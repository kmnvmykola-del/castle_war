"""16:9 authentic gameplay preview for the Roblox experience page."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from build_promo_video import ROOT,OUT,FFMPEG,run,FONT

def main():
    parts=[]
    for name,source,start,duration,caption in [
        ('battle','gameplay-v016.mp4',18,20,'Send troops along connected roads'),
        ('storm','shop-v016.mp4',2,1.7,'Complete sets: armies, buildings and roads'),
        ('dragon','shop-v016-dragon-oracle.mp4',2,1.7,'Complete sets: armies, buildings and roads'),
        ('stars','shop-v016-dragon-oracle.mp4',20,1.6,'Complete sets: armies, buildings and roads'),
        ('maps','editor-v016.mp4',2,5,'Create and play your own maps'),
    ]:
        overlay=Image.new('RGBA',(1920,1080));d=ImageDraw.Draw(overlay)
        d.rounded_rectangle((1180,24,1896,90),radius=14,fill=(10,20,34,225))
        d.text((1210,34),'FRONTIER KINGDOMS',font=ImageFont.truetype(str(FONT),38),fill=(239,245,251))
        d.rounded_rectangle((500,984,1896,1056),radius=14,fill=(10,20,34,225))
        d.text((530,993),caption,font=ImageFont.truetype(str(FONT),36),fill=(221,184,109))
        banner=OUT/f'roblox-trailer-{name}.png';overlay.save(banner)
        video=OUT/f'roblox-trailer-{name}.mp4';parts.append(video)
        run(['-ss',start,'-i',OUT/source,'-loop','1','-framerate','30','-i',banner,
             '-filter_complex','[0:v]scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2,fps=30[game];[game][1:v]overlay=0:0:shortest=1,format=yuv420p[out]',
             '-map','[out]','-an','-t',duration,'-r','30','-video_track_timescale','15360','-c:v','libx264','-crf','19','-preset','fast','-threads','3',video])
    listing=OUT/'roblox-trailer-concat.txt';listing.write_text(''.join(f"file '{p.name}'\n"for p in parts),encoding='utf8')
    final=OUT/'Frontier-Kingdoms-Roblox-Trailer.mp4'
    run(['-f','concat','-safe','0','-i',listing,'-i',ROOT/'assets/audio/original/battle.wav',
         '-filter_complex','[1:a]atrim=0:30,asetpts=PTS-STARTPTS,volume=0.9,alimiter=limit=0.9,afade=t=in:d=0.4,afade=t=out:st=28:d=2[a]',
         '-map','0:v','-map','[a]','-c:v','copy','-c:a','aac','-b:a','192k','-t','30','-movflags','+faststart',final])
    run(['-v','error','-i',final,'-f','null','NUL'])
    print(final)

if __name__=='__main__':main()
