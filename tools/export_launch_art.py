"""Copy selected generated originals and export Roblox upload dimensions."""
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
GENERATED=Path('C:/Users/Kolia/.codex/generated_images/01a10d67-81b3-7910-be08-a0ee060f83ef')
OUT=ROOT/'assets/promo'
files={
    'frontier-kingdoms-icon':'exec-03512c9e-741b-486a-8a7c-43c1f42e5fd0.png',
    'frontier-kingdoms-thumbnail':'exec-77c191df-6284-4939-a212-ae94f9484ddf.png',
    'pass-storm':'exec-df12457e-c618-4510-9412-f99705fc1cc6.png',
    'pass-dragon':'exec-b54e208f-6be3-48f3-bcff-2fa9cc0fb080.png',
    'pass-oracle':'exec-14d059fd-ee64-4b07-becb-3d6a1a12e4fd.png',
}
for stem,filename in files.items():
    master=OUT/f'{stem}-master.png'
    if not master.exists():shutil.copy2(GENERATED/filename,master)
    size=(1920,1080) if 'thumbnail' in stem else (512,512)
    width,height=size
    output=OUT/f'{stem}.png'
    subprocess.run([str(ROOT/'build/release/ffmpeg.exe'),'-hide_banner','-loglevel','error','-y','-i',str(master),'-vf',f'scale={width}:{height}:force_original_aspect_ratio=decrease:flags=lanczos,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2','-frames:v','1',str(output)],check=True)
    print(f'{output}: {width}x{height}')
