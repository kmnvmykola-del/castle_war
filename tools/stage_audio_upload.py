"""Make lossless upload copies with descriptive English Roblox asset names."""
from pathlib import Path
import shutil

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/release/audio-upload'
OUT.mkdir(exist_ok=True)
NAMES={'menu':'Frontier Dawn','battle':'March of the Banners','click':'Frontier Kingdoms - UI Click','select':'Frontier Kingdoms - Select Building','order':'Frontier Kingdoms - Army Order','place':'Frontier Kingdoms - Place Building','error':'Frontier Kingdoms - Error','chest':'Frontier Kingdoms - Chest Reveal','victory':'Frontier Kingdoms - Victory','defeat':'Frontier Kingdoms - Defeat'}
for stem,name in NAMES.items():
    target=OUT/(name+'.wav')
    shutil.copy2(ROOT/'assets/audio/original'/(stem+'.wav'),target)
    print(target)
