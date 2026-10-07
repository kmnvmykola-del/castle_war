"""Download the official portable Blender archive using verified HTTP ranges."""
from pathlib import Path
import concurrent.futures
import subprocess
import zipfile

OUT=Path(__file__).resolve().parents[1]/'build/blender-runtime'
URL='https://download.blender.org/release/Blender4.5/blender-4.5.0-windows-x64.zip'
TOTAL=399946398
COUNT=12

def fetch(i):
    start=TOTAL*i//COUNT;end=TOTAL*(i+1)//COUNT-1
    path=OUT/f'blender-part-{i:02}.bin'
    if path.exists() and path.stat().st_size==end-start+1:return path
    header=OUT/f'blender-part-{i:02}.headers'
    subprocess.run(['curl.exe','-L','--fail','--silent','--show-error','--retry','2',
        '--range',f'{start}-{end}','--dump-header',str(header),'--output',str(path),URL],check=True)
    assert f'content-range: bytes {start}-{end}/{TOTAL}'in header.read_text().lower()
    assert path.stat().st_size==end-start+1
    print(f'Blender part {i+1}/{COUNT} verified',flush=True)
    return path

with concurrent.futures.ThreadPoolExecutor(max_workers=COUNT)as pool:
    list(pool.map(fetch,range(COUNT)))
archive=OUT/'blender-complete.zip'
with archive.open('wb')as dest:
    for i in range(COUNT):
        with (OUT/f'blender-part-{i:02}.bin').open('rb')as source:
            while chunk:=source.read(1024*1024):dest.write(chunk)
assert archive.stat().st_size==TOTAL
with zipfile.ZipFile(archive)as package:
    assert package.testzip()is None
    for name in package.namelist():
        resolved=(OUT/name).resolve();assert resolved.is_relative_to(OUT.resolve())
    package.extractall(OUT)
print('BLENDER_READY',OUT/'blender-4.5.0-windows-x64/blender.exe',flush=True)
