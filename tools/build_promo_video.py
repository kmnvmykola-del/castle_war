"""Render an English vertical trailer from the recorded Roblox gameplay.

The recorded clips are real Studio sessions. Art is illustrative; transitions,
captions and the original soundtrack are added during editing.
"""
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/release'
ART=ROOT/'assets/promo'
FFMPEG=OUT/'ffmpeg.exe'
FONT=Path('C:/Windows/Fonts/segoeuib.ttf')
REGULAR=Path('C:/Windows/Fonts/segoeui.ttf')
GOLD=(221,184,109)
WHITE=(239,245,251)

def run(args):
    subprocess.run([str(FFMPEG),'-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)

def text(draw,xy,value,size=64,fill=WHITE,regular=False):
    font=ImageFont.truetype(str(REGULAR if regular else FONT),size)
    draw.text(xy,value,font=font,fill=fill,anchor='ma',spacing=18,align='center')

def card(name,title,subtitle,footer,icon=False):
    im=Image.new('RGB',(1080,1920),(10,20,34));d=ImageDraw.Draw(im)
    # A restrained frame keeps the recorded game readable on a phone.
    for y in range(1920):
        v=int(10+8*(1-abs(y-900)/1100))
        d.line((0,y,1080,y),fill=(max(8,v),max(16,v+10),max(29,v+25)))
    d.line((70,112,1010,112),fill=GOLD,width=3)
    text(d,(540,160),'FRONTIER KINGDOMS',38,GOLD)
    text(d,(540,246),title,74)
    text(d,(540,430),subtitle,32,(176,194,213),True)
    if icon:
        emblem=Image.open(ART/'frontier-kingdoms-icon.png').convert('RGB').resize((800,800),Image.Resampling.LANCZOS)
        im.paste(emblem,(140,540))
    else:
        d.rounded_rectangle((44,550,1036,1320),radius=26,fill=(4,9,17),outline=(65,89,114),width=3)
    text(d,(540,1430),footer,50)
    text(d,(540,1540),'COMMAND  /  CAPTURE  /  CONQUER',28,GOLD)
    text(d,(540,1690),'PLAY ON ROBLOX',35)
    text(d,(540,1750),'Search: Frontier Kingdoms',29,(176,194,213),True)
    path=OUT/f'promo-{name}.png';im.save(path);return path

def main():
    plans=[
        ('intro',1.8,'YOUR ARMY.\nYOUR KINGDOM.','A strategy game on Roblox','Choose your next move.',None,0,None),
        ('battle',12,'COMMAND.\nCAPTURE.','Send troops along connected roads.','Take the frontier.', 'gameplay-v016.mp4',20,'null'),
        ('storm',2,'ONE SET.\nA NEW LOOK.','Armies, buildings and roads.','Collect complete cosmetic sets.','shop-v016.mp4',2,'null'),
        ('dragon',2,'ONE SET.\nA NEW LOOK.','Armies, buildings and roads.','Collect complete cosmetic sets.','shop-v016-dragon-oracle.mp4',2,'null'),
        ('stars',2,'ONE SET.\nA NEW LOOK.','Armies, buildings and roads.','Collect complete cosmetic sets.','shop-v016-dragon-oracle.mp4',20,'null'),
        ('editor',5,'BUILD YOUR\nBATTLEFIELD.','Create and play your own maps.','Make your own strategy.','editor-v016.mp4',2,'null'),
        ('outro',4.2,'THE FRONTIER\nIS YOURS.','Vs AI  /  PvP  /  Map Editor','Play Frontier Kingdoms.',None,0,None),
    ]
    segments=[]
    for name,duration,title,subtitle,footer,clip,start,crop in plans:
        background=card(name,title,subtitle,footer,clip is None)
        path=OUT/f'promo-segment-{name}.mp4';segments.append(path)
        if clip:
            # Wide UI remains intact; the battlefield gets a closer crop.
            graph=f'[1:v]{crop},scale=980:760:force_original_aspect_ratio=decrease,pad=980:760:(ow-iw)/2:(oh-ih)/2:color=0x040911,setsar=1,fps=30[v];[0:v][v]overlay=50:555:shortest=1,fps=30,format=yuv420p[out]'
            args=['-loop','1','-framerate','30','-i',background,'-ss',start,'-i',OUT/clip,'-filter_complex',graph,'-map','[out]']
        else:
            args=['-loop','1','-i',background,'-vf','fps=30,format=yuv420p']
        run([*args,'-t',duration,'-an','-r','30','-video_track_timescale','15360','-c:v','libx264','-preset','fast','-crf','19','-threads','3',path])
    listing=OUT/'promo-concat.txt'
    listing.write_text(''.join(f"file '{p.name}'\n"for p in segments),encoding='utf8')
    final=OUT/'Frontier-Kingdoms-Shorts.mp4'
    run(['-f','concat','-safe','0','-i',listing,'-i',ROOT/'assets/audio/original/battle.wav',
         '-filter_complex','[1:a]atrim=0:29,asetpts=PTS-STARTPTS,volume=0.90,alimiter=limit=0.90,afade=t=in:d=0.5,afade=t=out:st=27.5:d=1.5[a]',
         '-map','0:v','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-t','29','-movflags','+faststart',final])
    run(['-ss','0.8','-i',final,'-frames:v','1',ART/'shorts-cover.png'])
    # Additional listing images show actual gameplay and the real map editor.
    for name,clip,start,label in [('gameplay','gameplay-v016.mp4',42,'COMMAND YOUR ARMY'),('editor','editor-v016.mp4',2,'BUILD YOUR BATTLEFIELD')]:
        frame=OUT/f'thumbnail-{name}-capture.png'
        run(['-ss',start,'-i',OUT/clip,'-vf','scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2','-frames:v','1',frame])
        image=Image.open(frame).convert('RGB');draw=ImageDraw.Draw(image)
        draw.rectangle((0,0,1920,140),fill=(10,20,34))
        draw.text((70,30),'FRONTIER KINGDOMS',font=ImageFont.truetype(str(FONT),64),fill=WHITE)
        draw.rectangle((0,938,1920,1080),fill=(10,20,34))
        draw.text((70,968),label,font=ImageFont.truetype(str(FONT),58),fill=GOLD)
        image.save(ART/f'frontier-kingdoms-{name}-thumbnail.png')
    (OUT/'PROMO_POST_EN.txt').write_text(
        'Title: Your army. Your kingdom. | Frontier Kingdoms #Roblox\n\n'
        'Command your troops, capture the frontier, collect complete cosmetic sets, '
        'and build your own battlefield. Play Frontier Kingdoms on Roblox!\n\n'
        'https://www.roblox.com/games/81963222072062/Frontier-Kingdoms\n\n'
        '#Roblox #FrontierKingdoms #RobloxGames #StrategyGames #Shorts\n\n'
        'Original game footage and music. Key art is illustrative.\n'
        'Before posting, verify public access and choose the destination channel.\n',encoding='utf8')
    print(f'{final}: 29 seconds, 1080 x 1920, 30 FPS, original soundtrack')

if __name__=='__main__':main()
