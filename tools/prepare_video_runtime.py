"""Extract only FFmpeg from its downloaded imageio wheel into the project."""
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[1]
wheel=next((ROOT/'build/release').glob('imageio_ffmpeg-*-win_amd64.whl'))
with zipfile.ZipFile(wheel) as archive:
    names=[name for name in archive.namelist() if name.startswith('imageio_ffmpeg/binaries/') and name.endswith('.exe')]
    assert len(names)==1,names
    output=ROOT/'build/release/ffmpeg.exe'
    output.write_bytes(archive.read(names[0]))
print(output)
