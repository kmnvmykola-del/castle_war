"""Extract required official Blender files, verifying every ZIP CRC."""
from pathlib import Path
import zipfile
import subprocess
import concurrent.futures
ROOT=Path(__file__).resolve().parents[1]/'build/blender-runtime'
TOTAL=399946398;CD=398916563
URL='https://download.blender.org/release/Blender4.5/blender-4.5.0-windows-x64.zip'
archive=ROOT/'blender-selective.zip'
with archive.open('wb')as f:
    f.truncate(TOTAL);f.seek(CD);f.write((ROOT/'blender-central.bin').read_bytes())
with zipfile.ZipFile(archive)as z:
    infos=z.infolist()
    wanted=[i for i in infos if not i.is_dir()and '/cycles/lib/'not in i.filename
            and '/cycles/license/'not in i.filename and not i.filename.endswith(('.pdb','.blend'))]
    # Blender's startup.blend is needed; large sample asset .blend files are not.
    wanted.extend(i for i in infos if i.filename.endswith('/startup.blend'))
    wanted=list({i.filename:i for i in wanted}.values())
prefix=(ROOT/'blender.zip').stat().st_size
with archive.open('r+b')as dest,(ROOT/'blender.zip').open('rb')as source:
    remaining=prefix
    while remaining:
        blob=source.read(min(1024*1024,remaining));dest.write(blob);remaining-=len(blob)
requests=[]
for i in wanted:
    end=i.header_offset+30+len(i.filename.encode())+i.compress_size+1024
    if end<=prefix:continue
    first=i.header_offset//1048576;last=min(CD-1,end)//1048576
    requests.extend(range(first,last+1))
chunks=sorted(set(requests))
print('BLENDER_MINIMAL',len(wanted),'files;',len(chunks),'MiB chunks required beyond downloaded prefix',flush=True)

def fetch(chunk):
    start=chunk*1048576;end=min(TOTAL-1,start+1048575);path=ROOT/f'runtime-chunk-{chunk:04}.bin'
    if not path.exists()or path.stat().st_size!=end-start+1:
        subprocess.run(['curl.exe','-L','--fail','--silent','--show-error','--retry','6','--retry-all-errors','--max-time','90',
            '--range',f'{start}-{end}','--output',str(path),URL],check=True)
    assert path.stat().st_size==end-start+1
    return start,path
with concurrent.futures.ThreadPoolExecutor(max_workers=3)as pool:
    for n,(start,path)in enumerate(pool.map(fetch,chunks)):
        with archive.open('r+b')as dest:dest.seek(start);dest.write(path.read_bytes())
        if n%20==0:print('Blender components',n+1,'/',len(chunks),flush=True)
with zipfile.ZipFile(archive)as z:
    for i in wanted:
        target=(ROOT/i.filename).resolve();assert target.is_relative_to(ROOT.resolve())
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(i))
print('BLENDER_READY',ROOT/'blender-4.5.0-windows-x64/blender.exe',flush=True)
