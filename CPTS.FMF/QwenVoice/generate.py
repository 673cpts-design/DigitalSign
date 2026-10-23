"""Offline Qwen cloning using reference audio AND its transcript."""
import argparse
import contextlib
import json
import logging
from logging.handlers import RotatingFileHandler
import os
from pathlib import Path
import re
import socket
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent
os.environ['HF_HOME'] = str(ROOT / 'cache')
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'
os.environ['HF_HUB_DISABLE_TELEMETRY'] = '1'
os.environ['TOKENIZERS_PARALLELISM'] = 'false'


def block_network():
    def denied(*args, **kwargs):
        raise RuntimeError('Network access is disabled during generation. Run Setup.cmd to provision missing files.')
    socket.create_connection = denied
    socket.socket.connect = denied
    socket.socket.connect_ex = denied


def split_text(text, limit):
    text = ' '.join(text.split())
    if not text:
        raise ValueError('script.txt is empty.')
    chunks, current = [], ''
    for sentence in re.split(r'(?<=[.!?])\s+', text):
        if current and len(current) + len(sentence) + 1 > limit:
            chunks.append(current)
            current = ''
        for word in sentence.split():
            if len(word) > limit:
                raise ValueError('Script contains an excessively long word or URL.')
            candidate = (current + ' ' + word).strip()
            if len(candidate) > limit:
                chunks.append(current)
                current = word
            else:
                current = candidate
    if current:
        chunks.append(current)
    return chunks


def path_for(name):
    return (ROOT / name).resolve()


def reference_path(value):
    if value != 'auto':
        path = path_for(value)
        if not path.is_file():
            raise FileNotFoundError(f'Reference audio not found: {path}')
        return path
    found = [p for p in ROOT.iterdir() if p.is_file() and p.stem.lower() == 'reference'
             and p.suffix.lower() in ('.wav', '.mp3', '.flac')]
    if len(found) != 1:
        raise ValueError('Place exactly one reference.wav, reference.mp3, or reference.flac in this folder, or set reference explicitly in settings.json.')
    return found[0].resolve()


@contextlib.contextmanager
def run_lock():
    with open(ROOT / 'generation.lock', 'a+b') as handle:
        handle.seek(0, 2)
        if handle.tell() == 0:
            handle.write(b'0'); handle.flush()
        handle.seek(0)
        if os.name == 'nt':
            import msvcrt
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == 'nt':
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def run(args):
    cfg = json.loads((ROOT / 'settings.json').read_text(encoding='utf-8-sig'))
    size = args.model or cfg['model']
    if size not in ('0.6B', '1.7B'):
        raise ValueError('model must be 0.6B or 1.7B.')
    limit = int(cfg['max_chunk_characters'])
    pause = float(cfg['pause_seconds'])
    if not 80 <= limit <= 500 or not 0 <= pause <= 2:
        raise ValueError('Use max_chunk_characters 80-500 and pause_seconds 0-2.')
    if not args.check:
        reference = reference_path(cfg['reference'])
        transcript_path = path_for(cfg['reference_transcript'])
        transcript = transcript_path.read_text(encoding='utf-8-sig').strip()
        if not transcript or transcript.startswith('REPLACE THIS'):
            raise ValueError('Fill reference.txt with the exact words spoken in the reference recording. It is separate from script.txt.')
        script_path = path_for(cfg['script'])
        text = 'This is a test of the local Qwen voice clone.' if args.test else script_path.read_text(encoding='utf-8-sig')
        chunks = split_text(text, limit)
        output = path_for(args.output or (f'test-{size}.wav' if args.test else cfg['output']))
        if output.suffix.lower() != '.wav':
            raise ValueError('Output must be a WAV file.')
        protected = {reference, transcript_path, script_path, ROOT / 'settings.json', Path(__file__).resolve()}
        if output in protected or (ROOT / 'models') in output.parents:
            raise ValueError('Output path would overwrite an input or model file.')
    model_path = ROOT / 'models' / size
    if not (model_path / 'download-complete.json').is_file():
        raise FileNotFoundError(f'Model {size} is not downloaded completely. Run Setup.cmd.')
    block_network()
    import numpy as np
    import soundfile as sf
    import torch
    from qwen_tts import Qwen3TTSModel
    if not torch.cuda.is_available():
        raise RuntimeError('CUDA is unavailable. Check your NVIDIA driver and the CUDA PyTorch installation.')
    torch.manual_seed(int(cfg['seed']))
    np.random.seed(int(cfg['seed']))
    if not args.check:
        audio, sample_rate = sf.read(str(reference), dtype='float32', always_2d=True)
        audio = audio.mean(axis=1)
        if not len(audio) or not np.isfinite(audio).all() or np.max(np.abs(audio)) < 0.0001:
            raise ValueError('Reference audio is empty, silent, or contains invalid samples.')
        duration = len(audio) / sample_rate
        if duration < 3:
            raise ValueError('Use at least three seconds of clear reference speech.')
        logging.info('Reference: %.1f seconds. Entire recording supplied; no automatic trimming.', duration)
        if duration > 30:
            logging.info('Long references increase memory use. If quality is poor, compare a shorter excerpt with its matching transcript.')
    dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16
    started = time.perf_counter()
    logging.info('Loading %s on %s, using SDPA and %s.', size, torch.cuda.get_device_name(0), dtype)
    model = Qwen3TTSModel.from_pretrained(str(model_path), device_map='cuda:0', dtype=dtype,
                                        attn_implementation='sdpa', local_files_only=True)
    if args.check:
        logging.info('PASS: %s loaded locally on GPU with network blocked. This is a loading check, not a speech test.', size)
        return
    with torch.inference_mode():
        prompt = model.create_voice_clone_prompt(ref_audio=(audio, sample_rate), ref_text=transcript,
                                                 x_vector_only_mode=False)
    output.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=output.stem + '-', suffix='.pending.wav', dir=output.parent)
    os.close(fd)
    pending = Path(name)
    try:
        # Sample rate is returned by the model; open the writer after the first section.
        with contextlib.ExitStack() as stack:
            writer, output_rate = None, None
            for i, section in enumerate(chunks):
                logging.info('Generating section %d of %d (%d characters).', i + 1, len(chunks), len(section))
                with torch.inference_mode():
                    wavs, rate = model.generate_voice_clone(text=section, language=cfg['language'],
                        voice_clone_prompt=prompt, non_streaming_mode=True, max_new_tokens=2048)
                samples = np.asarray(wavs[0], dtype=np.float32).reshape(-1)
                if rate <= 0 or len(samples) < rate // 5 or not np.isfinite(samples).all():
                    raise RuntimeError(f'Invalid generated audio in section {i + 1}.')
                peak = float(np.max(np.abs(samples)))
                if peak < 0.0001:
                    raise RuntimeError(f'Silent generated audio in section {i + 1}.')
                if peak > 0.98:
                    samples *= 0.98 / peak
                # Apply cleanup once, at the start of the complete recording.
                # Defaults work with existing settings.json files.
                if i == 0:
                    trim = float(cfg.get('trim_start_seconds', 0.22))
                    fade_ms = float(cfg.get('fade_in_ms', 5))
                    if not np.isfinite(trim) or not np.isfinite(fade_ms) or trim < 0 or fade_ms < 0:
                        raise ValueError('Start trim and fade must be finite, non-negative values.')
                    cut = round(rate * trim)
                    if cut >= len(samples):
                        raise ValueError('Start trim would remove the entire first section.')
                    samples = samples[cut:].copy()
                    fade = min(round(rate * fade_ms / 1000), len(samples))
                    if fade > 0:
                        samples[:fade] *= np.linspace(0.0, 1.0, fade, dtype=np.float32)
                    logging.info('Start cleanup: trimmed %.3fs; fade-in %.1fms.', cut / rate, fade * 1000 / rate)
                if writer is None:
                    output_rate = rate
                    writer = stack.enter_context(sf.SoundFile(str(pending), mode='w', samplerate=rate,
                                                              channels=1, subtype='FLOAT'))
                elif rate != output_rate:
                    raise RuntimeError('Model sample rate changed between sections.')
                if i:
                    writer.write(np.zeros(round(rate * pause), dtype=np.float32))
                writer.write(samples)
        # Normalize the complete message, including all generated sections.
        # The pending file is floating point to preserve quiet audio before gain.
        from qwen_volume import normalize_announcement
        completed, completed_rate = sf.read(str(pending), dtype='float64')
        completed, before_lufs, after_lufs = normalize_announcement(
            completed, completed_rate,
            target=float(cfg.get('output_loudness_lufs', -16.0)),
            ceiling_db=float(cfg.get('output_peak_db', -1.5)))
        sf.write(str(pending), completed, completed_rate, subtype='PCM_16')
        logging.info('Output loudness: %.1f -> %.1f LUFS; target %.1f LUFS.',
                     before_lufs, after_lufs, float(cfg.get('output_loudness_lufs', -16.0)))
        if abs(after_lufs - float(cfg.get('output_loudness_lufs', -16.0))) > 1.0:
            logging.warning('Peak limiting prevented reaching the loudness target within 1 LU.')
        info = sf.info(str(pending))
        if info.frames <= 0:
            raise RuntimeError('Generated WAV is empty.')
        os.replace(pending, output)
        logging.info('COMPLETE: %s | audio %.1fs | processing %.1fs', output, info.duration, time.perf_counter() - started)
    finally:
        pending.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', choices=['0.6B', '1.7B'])
    parser.add_argument('--output')
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--check', action='store_true')
    modes.add_argument('--test', action='store_true')
    args = parser.parse_args()
    (ROOT / 'logs').mkdir(exist_ok=True)
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s',
        handlers=[logging.StreamHandler(sys.stdout), RotatingFileHandler(ROOT / 'logs' / 'generation.log',
                   maxBytes=2_000_000, backupCount=3, encoding='utf-8')])
    try:
        with run_lock():
            run(args)
        return 0
    except Exception:
        logging.exception('FAILED. See the error above. No incomplete audio is published.')
        return 1


if __name__ == '__main__':
    sys.exit(main())
