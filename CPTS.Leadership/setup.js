
window.addEventListener('load', () => {
 const fallback = () => {document.body.classList.remove('webgl-ready');document.body.classList.add('no-curtains');};
 try {
  const curtains = new Curtains({container:'canvas',alpha:true,pixelRatio:Math.min(1.5,window.devicePixelRatio)});
  curtains.onError(fallback).onContextLost(() => {fallback();curtains.restoreContext();})
   .onContextRestored(() => {document.body.classList.remove('no-curtains');document.body.classList.add('webgl-ready');});
  let resizeFrame = 0;
  function refreshFlagSize() {
   cancelAnimationFrame(resizeFrame);
   resizeFrame = requestAnimationFrame(() => curtains.resize());
  }
  window.addEventListener('resize', refreshFlagSize);
  document.addEventListener('fullscreenchange', refreshFlagSize);
  const plane = new Plane(curtains, document.querySelector('.plane'), {
   vertexShader:`
        precision mediump float;

        // default mandatory variables
        attribute vec3 aVertexPosition;
        attribute vec2 aTextureCoord;

        uniform mat4 uMVMatrix;
        uniform mat4 uPMatrix;

        // texture matrix
        uniform mat4 uTextureMatrix0;

        // custom variables
        varying vec3 vVertexPosition;
        varying float vFlagShade;
        varying vec2 vTextureCoord;

        uniform float uTime;
        uniform float uSecondaryPhase;
        uniform float uFlutterPhase;
        uniform float uWind;
        uniform float uWaveScale;
        uniform float uFlutter;
        uniform vec3 uTieTop;
        uniform vec3 uTieBottom;
        uniform float uEdgeBow;

        void main() {
            vec3 vertexPosition = aVertexPosition;

            // x = 0 at the pole, x = 1 at the free edge.
            float x = (aVertexPosition.x + 1.0) * 0.5;
            float strength = pow(x, 1.35);
            float phase = x * uWaveScale - uTime + aVertexPosition.y * 0.75;
            float secondary = x * (uWaveScale * 1.82) - uSecondaryPhase - aVertexPosition.y * 1.2;
            float flutter = x * 31.0 - uFlutterPhase + aVertexPosition.y * 2.6;
            float ripple = sin(phase) + 0.28 * sin(secondary) + uFlutter * x * sin(flutter);
            // Two compliant rope attachments, with cloth bowing between them.
            float vertical = (aVertexPosition.y + 1.0) * 0.5;
            float bowEnvelope = 1.0 - aVertexPosition.y * aVertexPosition.y;
            float attachmentInfluence = exp(-4.5 * x);
            vec3 tieMotion = mix(uTieBottom, uTieTop, vertical);
            vec3 edgeMotion = tieMotion;
            edgeMotion.x += bowEnvelope * uEdgeBow;
            edgeMotion.z += bowEnvelope * (0.018 * uWind * sin(secondary) + 0.012 * sin(phase));
            edgeMotion.y -= 0.006 * bowEnvelope * (1.0 - min(uWind, 1.0));
            vertexPosition += edgeMotion * attachmentInfluence;
            vertexPosition.z += 0.16 * strength * uWind * ripple;
            vertexPosition.y += strength * uWind * (0.035 * sin(phase + 0.9) + 0.009 * uFlutter * sin(flutter));
            vertexPosition.x -= 0.035 * strength * uWind * (1.0 + sin(secondary));
            vFlagShade = 1.0 + strength * uWind * (0.17 * cos(phase) + 0.045 * cos(secondary) + 0.035 * uFlutter * x * cos(flutter));

            // set positions
            gl_Position = uPMatrix * uMVMatrix * vec4(vertexPosition, 1.0);

            // varyings
            vTextureCoord = aTextureCoord; // Map the whole image to the flag mesh without cropping.
            vVertexPosition = vertexPosition;
        }
    `,
   fragmentShader:`
        precision mediump float;

        varying vec3 vVertexPosition;
        varying float vFlagShade;
        varying vec2 vTextureCoord;

        uniform sampler2D uSampler0;

        void main( void ) {
            // our texture
            vec4 color = texture2D(uSampler0, vTextureCoord);
            gl_FragColor = vec4(color.rgb * vFlagShade, color.a);
        }
    `,
   widthSegments:100,heightSegments:50,fov:35,
   uniforms:{
    time:{name:'uTime',type:'1f',value:0},
    secondary:{name:'uSecondaryPhase',type:'1f',value:0},
    flutterPhase:{name:'uFlutterPhase',type:'1f',value:0},
    wind:{name:'uWind',type:'1f',value:1},
    scale:{name:'uWaveScale',type:'1f',value:11},
    flutter:{name:'uFlutter',type:'1f',value:0.05},
    tieTop:{name:'uTieTop',type:'3f',value:[0,0,0]},
    tieBottom:{name:'uTieBottom',type:'3f',value:[0,0,0]},
    edgeBow:{name:'uEdgeBow',type:'1f',value:0}

   }
  });
  // Random wind episodes blend smoothly instead of restarting a timeline.
  const rand = (a,b) => a + Math.random() * (b-a);
  const patterns = [
   {strength:[0.3,0.55],speed:[1.1,1.8],scale:[7,10],flutter:[0.01,0.05]},
   {strength:[0.65,0.95],speed:[2.1,3.2],scale:[9,12],flutter:[0.04,0.12]},
   {strength:[1.0,1.35],speed:[3.0,4.6],scale:[10,14],flutter:[0.12,0.24]},
   {strength:[0.65,1.1],speed:[1.8,3.6],scale:[6,9],flutter:[0.06,0.17]}
  ];
  let lastPattern = -1;
  function chooseWind() {
   let index;
   do {index = Math.floor(Math.random()*patterns.length);} while(index === lastPattern);
   lastPattern = index;
   const p = patterns[index];
   return Object.fromEntries(Object.entries(p).map(([k,v])=>[k,rand(...v)]));
  }
  let from = {strength:1,speed:2.8,scale:11,flutter:0.05};
  let target = chooseWind(), episodeStart = performance.now(), duration = rand(10000,26000);
  let previous = episodeStart, gust = 0, gustTarget = 0, nextGust = episodeStart;
  const phases = [0,0,0], tau = Math.PI*2;
  // Increase for looser ropes; decrease for a firmer attachment.
  const ROPE_GIVE = 1.0;
  const topRope = {p:[0,0,0],v:[0,0,0]};
  const bottomRope = {p:[0,0,0],v:[0,0,0]};
  const bowRope = {p:[0],v:[0]};
  function spring(state, target, dt, stiffness, damping) {
   // Substeps keep the damped spring stable during slow frames.
   const steps = Math.max(1, Math.ceil(dt / 0.012));
   const step = dt / steps;
   for(let j=0;j<steps;j++) for(let i=0;i<target.length;i++) {
    state.v[i] += ((target[i]-state.p[i])*stiffness-state.v[i]*damping)*step;
    state.p[i] += state.v[i]*step;
   }
  }
  function updateWind() {
   const now = performance.now(), dt = Math.min((now-previous)/1000,0.1);
   previous = now;
   let t = Math.min((now-episodeStart)/duration,1);
   const blend = t*t*t*(t*(t*6-15)+10);
   const w = {};
   for(const key of Object.keys(from)) w[key] = from[key] + (target[key]-from[key])*blend;
   if(t === 1) {from = w;target = chooseWind();episodeStart = now;duration = rand(10000,26000);}
   if(now >= nextGust) {gustTarget = rand(-0.16,0.22);nextGust = now+rand(1400,5200);}
   gust += (gustTarget-gust)*(1-Math.exp(-dt/1.3));
   const strength = Math.max(0.2,w.strength+gust);
   const speed = Math.max(0.6,w.speed+gust*1.8);
   phases[0] = (phases[0]+dt*speed)%tau;
   phases[1] = (phases[1]+dt*speed*1.463)%tau;
   phases[2] = (phases[2]+dt*(speed*2.317+0.8))%tau;
   // Wind pulls on elastic attachments; springs smooth the response.
   const p = phases[0], q = phases[1];
   spring(topRope, [
    0.003 + 0.004*strength*(1+Math.sin(p)),
    0.004*strength*Math.sin(q),
    0.009*strength*Math.sin(p)
   ], dt, 16, 7);
   spring(bottomRope, [
    0.004 + 0.005*strength*(1+Math.sin(q)),
    0.005*strength*Math.sin(p),
    0.012*strength*Math.sin(q)
   ], dt, 13, 6);
   spring(bowRope, [0.008+0.017*strength*(0.5+0.5*Math.sin(p))], dt, 10, 5);
   for(let i=0;i<3;i++) {
    plane.uniforms.tieTop.value[i] = topRope.p[i]*ROPE_GIVE;
    plane.uniforms.tieBottom.value[i] = bottomRope.p[i]*ROPE_GIVE;
   }
   plane.uniforms.edgeBow.value = bowRope.p[0]*ROPE_GIVE;
   plane.uniforms.time.value = phases[0];
   plane.uniforms.secondary.value = phases[1];
   plane.uniforms.flutterPhase.value = phases[2];
   plane.uniforms.wind.value = strength;
   plane.uniforms.scale.value = w.scale;
   plane.uniforms.flutter.value = w.flutter;
  }
  plane.onReady(() => {document.body.classList.add('webgl-ready');})
   .onRender(updateWind)
   .onError(fallback);
 } catch(error) {fallback();console.error(error);}
});
