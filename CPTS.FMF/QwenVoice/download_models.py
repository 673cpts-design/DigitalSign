"""Online provisioning only. Generation never invokes this downloader."""
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent
os.environ['HF_HOME'] = str(ROOT / 'cache')
os.environ['HF_HUB_DISABLE_TELEMETRY'] = '1'
from huggingface_hub import snapshot_download

REVISIONS = {
    '0.6B': '5d83992436eae1d760afd27aff78a71d676296fc',
    '1.7B': 'fd4b254389122332181a7c3db7f27e918eec64e3',
}
REQUIRED = ['config.json', 'generation_config.json', 'model.safetensors',
            'preprocessor_config.json', 'tokenizer_config.json', 'vocab.json', 'merges.txt',
            'speech_tokenizer/config.json', 'speech_tokenizer/model.safetensors',
            'speech_tokenizer/preprocessor_config.json']

for size, revision in REVISIONS.items():
    repo = f'Qwen/Qwen3-TTS-12Hz-{size}-Base'
    destination = ROOT / 'models' / size
    destination.mkdir(parents=True, exist_ok=True)
    marker = destination / 'download-complete.json'
    if marker.is_file():
        try:
            recorded = json.loads(marker.read_text(encoding='utf-8'))
        except (ValueError, OSError):
            recorded = {}
        if (recorded.get('revision') == revision and
                all((destination / name).is_file() and (destination / name).stat().st_size
                    for name in REQUIRED)):
            print(f'Reusing complete local model: {size}', flush=True)
            continue
    marker.unlink(missing_ok=True)
    print(f'Downloading {repo} including its speech tokenizer...', flush=True)
    snapshot_download(repo_id=repo, revision=revision, local_dir=str(destination), max_workers=4,
                      allow_patterns=['*.json', '*.safetensors', '*.txt', 'speech_tokenizer/*', 'README.md', 'LICENSE*'])
    for name in REQUIRED:
        file = destination / name
        if not file.is_file() or not file.stat().st_size:
            raise RuntimeError(f'Missing or empty model file: {file}')
    marker.write_text(json.dumps({'repo': repo, 'revision': revision}, indent=2), encoding='utf-8')
    print(f'Download complete: {size}', flush=True)
