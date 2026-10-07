"""Render simple code-drawn currency badges; no source images are edited."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
font=Path('C:/Windows/Fonts/arialbd.ttf')
out=ROOT/'assets/promo'
out.mkdir(exist_ok=True)
for amount,stacks in [(500,2),(1500,3),(3500,4)]:
    image=Image.new('RGB',(512,512),(12,25,40));draw=ImageDraw.Draw(image)
    draw.ellipse((35,35,477,477),fill=(21,43,61),outline=(184,144,65),width=7)
    draw.ellipse((53,53,459,459),outline=(43,71,87),width=2)
    for i in range(stacks):
        x=256+(i-(stacks-1)/2)*66
        height=3+i
        for j in range(height):
            y=300-j*18
            draw.rounded_rectangle((x-42,y-20,x+42,y+8),radius=12,fill=(182,118,34),outline=(236,181,63),width=2)
            draw.ellipse((x-42,y-27,x+42,y-2),fill=(246,198,83),outline=(255,226,138),width=2)
            draw.line((x-19,y-16,x+19,y-16),fill=(193,137,41),width=4)
    number=f'{amount:,}'
    draw.text((256,347),number,font=ImageFont.truetype(str(font),58),anchor='mm',fill=(255,241,208))
    draw.text((256,394),'COINS',font=ImageFont.truetype(str(font),24),anchor='mm',fill=(232,188,94))
    image.save(out/f'coins-{amount}.png')
    print(out/f'coins-{amount}.png')
