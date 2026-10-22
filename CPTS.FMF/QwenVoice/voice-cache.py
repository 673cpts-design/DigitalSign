"""Read announcement sheet and cache its selected voice. Uses Qwen's Python."""
import argparse
import csv
import io
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile
import uuid
from html.parser import HTMLParser
from pathlib import Path

MAX_DOWNLOAD = 200 * 1024 * 1024
MAX_EXPANDED = 300 * 1024 * 1024

def fetch(url, limit):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Cache-Control': 'no-cache'})
    with urllib.request.urlopen(req, timeout=90) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError('Download exceeds the permitted size.')
    return data

class DownloadForm(HTMLParser):
    def __init__(self):
        super().__init__()
        self.action = None
        self.fields = {}
        self.active = False
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'form':
            self.active = attrs.get('id') == 'download-form'
            if self.active:
                self.action = attrs.get('action')
        if tag == 'input' and self.active and attrs.get('name'):
            self.fields[attrs['name']] = attrs.get('value', '')
    def handle_endtag(self, tag):
        if tag == 'form':
            self.active = False

def download_zip(link):
    parsed = urllib.parse.urlparse(link)
    if parsed.scheme != 'https':
        raise ValueError('The ZIP link must use HTTPS.')
    if parsed.hostname == 'drive.google.com':
        match = re.search(r'/file/d/([\w-]+)', parsed.path)
        query = urllib.parse.parse_qs(parsed.query)
        file_id = match.group(1) if match else query.get('id', [''])[0]
        if not re.fullmatch(r'[\w-]+', file_id):
            raise ValueError('Could not identify the file in the Google Drive link.')
        params = {'id': file_id, 'export': 'download', 'confirm': 't'}
        if query.get('resourcekey'):
            params['resourcekey'] = query['resourcekey'][0]
        link = 'https://drive.usercontent.google.com/download?' + urllib.parse.urlencode(params)
    data = fetch(link, MAX_DOWNLOAD)
    if not zipfile.is_zipfile(io.BytesIO(data)):
        # Handle Drive's large-file confirmation form without executing page code.
        form = DownloadForm()
        form.feed(data.decode('utf-8', errors='replace'))
        action = urllib.parse.urlparse(form.action or '')
        if action.scheme == 'https' and action.hostname == 'drive.usercontent.google.com':
            url = form.action + ('&' if action.query else '?') + urllib.parse.urlencode(form.fields)
            data = fetch(url, MAX_DOWNLOAD)
    if not zipfile.is_zipfile(io.BytesIO(data)):
        raise ValueError('Link did not return a ZIP. Set the Drive ZIP to Anyone with the link / Viewer and allow downloads. Login, quota, or access restrictions cannot be handled automatically.')
    return data

def inspect_voice(folder):
    import soundfile as sf
    transcript = folder / 'reference.txt'
    audio = [folder / name for name in ('reference.wav', 'reference.mp3') if (folder / name).is_file()]
    if len(audio) != 1 or not transcript.is_file():
        raise ValueError('Voice requires reference.txt and exactly one reference.wav or reference.mp3.')
    text = transcript.read_text(encoding='utf-8-sig').strip()
    if not text or text.startswith('REPLACE THIS'):
        raise ValueError('Reference transcript is empty or a placeholder.')
    info = sf.info(str(audio[0]))
    if info.duration < 3:
        raise ValueError('Reference audio must contain at least 3 seconds.')
    return {'reference': str(audio[0].resolve()), 'reference_transcript': str(transcript.resolve())}

def cache_voice(root, name, link):
    # Preserve the spreadsheet name exactly; reject unsafe Windows folder names.
    if (not name or len(name) > 100 or name in ('.', '..') or
        re.search(r'[<>:"/\\|?*\x00-\x1f]', name) or name.endswith(('.', ' ')) or
        re.match(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)', name, re.I)):
        raise ValueError('Selected voice is not a valid Windows folder name.')
    root.mkdir(parents=True, exist_ok=True)
    folder = root / name
    if folder.is_dir():
        try:
            result = inspect_voice(folder)
            print('Using cached voice: ' + name, file=sys.stderr)
            return result
        except Exception as error:
            print('Cached voice is incomplete or invalid; downloading again: ' + str(error), file=sys.stderr)
    print('Downloading voice: ' + name, file=sys.stderr)
    data = download_zip(link)
    staging = Path(tempfile.mkdtemp(prefix='.download-', dir=root))
    try:
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            files = [entry for entry in archive.infolist() if not entry.is_dir()]
            if len(files) != 2 or sum(e.file_size for e in files) > MAX_EXPANDED:
                raise ValueError('ZIP must contain exactly two files, at most 300 MB expanded.')
            names = [e.filename.replace('\\', '/').split('/')[-1].lower() for e in files]
            if sorted(names) not in (['reference.mp3', 'reference.txt'], ['reference.txt', 'reference.wav']):
                raise ValueError('ZIP must contain reference.txt and either reference.wav or reference.mp3.')
            # Extract only approved basenames into our staging folder, never ZIP paths.
            for entry, name_in_zip in zip(files, names):
                with archive.open(entry) as source, (staging / name_in_zip).open('wb') as target:
                    shutil.copyfileobj(source, target)
        inspect_voice(staging)
        if folder.exists():
            # Keep any previous incomplete folder for inspection; never delete user files.
            backup = root / ('.invalid-' + uuid.uuid4().hex)
            folder.rename(backup)
        staging.rename(folder)
        return inspect_voice(folder)
    finally:
        if staging.exists():
            shutil.rmtree(staging)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sheet-url', required=True)
    parser.add_argument('--voice-root', required=True)
    parser.add_argument('--result', required=True)
    args = parser.parse_args()
    match = re.match(r'https://docs\.google\.com/spreadsheets/d/([\w-]+)', args.sheet_url)
    if not match:
        raise ValueError('Invalid Google Sheets URL.')
    gid = re.search(r'[?#&]gid=(\d+)', args.sheet_url)
    params = {'format': 'csv', 'gid': gid.group(1) if gid else '0'}
    url = 'https://docs.google.com/spreadsheets/d/' + match.group(1) + '/export?' + urllib.parse.urlencode(params)
    raw = fetch(url, 5 * 1024 * 1024).decode('utf-8-sig')
    if raw.lstrip().lower().startswith(('<!doctype', '<html')):
        raise ValueError('Spreadsheet requires sign-in; anonymous read access is required.')
    rows = list(csv.reader(io.StringIO(raw)))
    def cell(row, col):
        return rows[row-1][col-1].strip() if len(rows) >= row and len(rows[row-1]) >= col else ''
    message, play, selected = cell(2, 1), cell(2, 2).lower(), cell(4, 2)
    if not message:
        raise ValueError('A2 is empty.')
    if play not in ('on', 'off', 'yes', 'no'):
        raise ValueError('B2 must contain On/Off or Yes/No.')
    if not selected:
        raise ValueError('Select a voice in B4.')
    matches = [cell(row, 1) for row in range(10, len(rows)+1) if cell(row, 2).casefold() == selected.casefold()]
    if len(matches) != 1:
        raise ValueError('B4 must match exactly one voice name in B10 downward. Check missing or duplicate names.')
    result = cache_voice(Path(args.voice_root), selected, matches[0])
    result.update(message=message, play=play, voice=selected)
    Path(args.result).write_text(json.dumps(result, ensure_ascii=False), encoding='utf-8')

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('VOICE SELECTION FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
