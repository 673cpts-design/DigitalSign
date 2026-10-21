/* Awards absolute bottom-left "Who" panel: Swiper 11 + SwiperGL, random
   shaders, 1200ms. Two reusable GL textures animate stills/video snapshots;
   the original media element renders at rest for sharp, transparent playback. */
(() => {
  'use strict';
  const panel=document.getElementById('media-panel'), live=document.getElementById('live-media');
  const container=document.getElementById('gl-transition'), wrapper=container.querySelector('.swiper-wrapper');
  let playlist=[], pending=null, signature='', index=-1, current=null, running=false;
  let timer, watchdog, token=0, request=null, swiper=null, enginePromise=null;
  const failed=new Set(), WIDTH=1920, HEIGHT=1080;
  const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
  function snapshot(media) {
    const canvas=document.createElement('canvas'); canvas.width=WIDTH;canvas.height=HEIGHT;
    const w=media.videoWidth||media.naturalWidth, h=media.videoHeight||media.naturalHeight;
    if(!w||!h)throw Error('No decoded dimensions');
    const scale=Math.min(WIDTH/w,HEIGHT/h);
    canvas.getContext('2d').drawImage(media,(WIDTH-w*scale)/2,(HEIGHT-h*scale)/2,w*scale,h*scale);
    return canvas;
  }
  async function prepare(item) {
    const media=document.createElement(item.kind==='video'?'video':'img');
    if(item.kind==='video'){
      media.muted=true;media.defaultMuted=true;media.playsInline=true;
      media.setAttribute('muted','');media.setAttribute('playsinline','');media.preload='auto';
    }else{media.alt='';media.draggable=false;media.decoding='async';}
    await new Promise((resolve,reject)=>{
      const timeout=setTimeout(()=>done(Error('load timeout')),30000);
      const done=error=>{
        clearTimeout(timeout);media.onload=media.onloadeddata=media.onerror=null;
        if(error){media.removeAttribute('src'); if(item.kind==='video')media.load();reject(error);}
        else resolve();
      };
      media.onerror=()=>done(Error('unsupported or damaged media'));
      if(item.kind==='video')media.onloadeddata=()=>done();
      else media.onload=()=>done();
      media.src=item.src;
    });
    return media;
  }
  async function engine() {
    if(enginePromise)return enginePromise;
    enginePromise=(async()=>{
      const blank=document.createElement('canvas');blank.width=WIDTH;blank.height=HEIGHT;
      for(let n=0;n<2;n++){
        const slide=document.createElement('div');slide.className='swiper-slide';
        const image=document.createElement('img');image.className='swiper-gl-image';image.src=blank.toDataURL();
        slide.append(image);wrapper.append(slide);
      }
      swiper=new Swiper(container,{
        modules:[SwiperGL],effect:'gl',gl:{shader:'random'},
        creativeEffect:{limitProgress:5,prev:{shadow:true},next:{shadow:true}},
        speed:1200,watchSlidesProgress:true,allowTouchMove:false,simulateTouch:false,
        autoplay:false,loop:false,resizeObserver:true,updateOnWindowResize:true
      });
      const deadline=Date.now()+10000;
      while(!swiper.gl?.initialized||!swiper.gl?.material){
        if(Date.now()>deadline)throw Error('WebGL initialization unavailable');
        await sleep(25);
      }
      const gl=swiper.gl;
      gl.renderer.dpr=1; gl.resize();
      const render=gl.renderer.render.bind(gl.renderer);
      gl.renderer.render=(options)=>{if(container.style.visibility==='visible')render(options);};
      // Some original artistic shaders force opacity. Mask empty margins without
      // changing the original shader's color/deformation calculations.
      const original=gl.createMaterial;
      gl.createMaterial=function(){
        const source=this.shader.fragment;
        this.shader.fragment=source.replace(/void\s+main\s*\(\s*\)/,'void originalMain()')+
          '\nvoid main(){ originalMain(); float maskAlpha=max(texture2D(texture1,vUv).a,texture2D(texture2,vUv).a); gl_FragColor.a=min(gl_FragColor.a,maskAlpha); }';
        try{return original.call(this);}finally{this.shader.fragment=source;}
      };
      gl.replaceShader('random');
      return gl;
    })();
    return enginePromise;
  }
  async function transition(from,to) {
    try{
      const gl=await engine();
      const start=swiper.activeIndex, end=start===0?1:0;
      gl.textures[start].image=snapshot(from);gl.textures[start].needsUpdate=true;
      gl.textures[end].image=snapshot(to);gl.textures[end].needsUpdate=true;
      gl.material.uniforms.texture1.value=gl.textures[start];
      if(gl.shader.vertex)gl.vertexMaterial.uniforms.texture1.value=gl.textures[end];
      else gl.material.uniforms.texture2.value=gl.textures[end];
      gl.material.uniforms.progress.value=0;
      gl.resize();
      container.style.visibility='visible';live.style.visibility='hidden';
      swiper.slideTo(end,1200);
      await sleep(1250);
    }catch(error){console.warn('GL transition unavailable; showing next media:',error.message);}
    finally{container.style.visibility='hidden';live.style.visibility='visible';}
  }
  function release(media){
    if(!media)return;
    media.onended=media.onerror=media.ontimeupdate=null;
    if(media.tagName==='VIDEO'){media.pause();media.removeAttribute('src');media.load();}
    media.remove();
  }
  function schedule(){
    clearTimeout(timer);clearTimeout(watchdog);
    const mine=++token, media=current;
    if(!media)return;
    const go=()=>{if(mine===token)next();};
    if(media.tagName==='IMG'){timer=setTimeout(go,2000);return;}
    media.currentTime=0;media.muted=true;
    const fail=reason=>{
      if(mine!==token)return;
      console.warn('Skipping video:',playlist[index]?.src,reason);
      failed.add(playlist[index]?.src);go();
    };
    let position=-1;
    const arm=()=>{clearTimeout(watchdog);watchdog=setTimeout(()=>fail('no progress for 30 seconds'),30000);};
    media.onended=go;media.onerror=()=>fail('video playback error');
    media.ontimeupdate=()=>{if(mine===token&&media.currentTime>position){position=media.currentTime;arm();}};
    arm();media.play().catch(e=>fail(e.message));
  }
  async function next() {
    if(running)return;
    running=true;++token;clearTimeout(timer);clearTimeout(watchdog);
    if(current?.tagName==='VIDEO')current.pause();
    if(pending!==null){playlist=pending;pending=null;index=-1;failed.clear();}
    if(!playlist.length){
      release(current);current=null;live.replaceChildren();running=false;return;
    }
    for(let attempt=0;attempt<playlist.length;attempt++){
      index=(index+1)%playlist.length;
      const item=playlist[index];if(failed.has(item.src))continue;
      try{
        if(playlist.length===1&&current?.getAttribute('src')===item.src){
          running=false;schedule();return;
        }
        const media=await prepare(item);
        if(current)await transition(current,media);
        release(current);current=media;live.replaceChildren(media);
        running=false;schedule();return;
      }catch(error){failed.add(item.src);console.warn('Skipping media:',item.src,error.message);}
    }
    release(current);current=null;live.replaceChildren();running=false;
    timer=setTimeout(()=>{failed.clear();next();},30000);
  }
  window.receiveMediaPlaylist=data=>{
    if(!data||!Array.isArray(data.items))return;
    const items=data.items.filter(x=>x&&typeof x.src==='string'&&['image','video'].includes(x.kind));
    const sig=JSON.stringify(items);if(sig===signature)return;
    signature=sig;pending=items;
    if(!current&&!running)next();
  };
  function refresh(){
    if(request)return;
    const script=document.createElement('script');request=script;
    const done=()=>{clearTimeout(timeout);script.remove();if(request===script)request=null;};
    const timeout=setTimeout(done,10000);
    script.onload=done;script.onerror=done;script.src='./media-playlist.js?t='+Date.now();document.head.append(script);
  }
  refresh();setInterval(refresh,5000);
})();
