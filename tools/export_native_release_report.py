"""Persist the observed native Studio QA; does not simulate Roblox rendering."""
from pathlib import Path
import json,re

ROOT=Path(__file__).resolve().parents[1]
LOGS=Path('C:/Users/Kolia/AppData/Local/Roblox/logs')

def main():
    players={}
    summary=re.compile(r'KINGDOMS_NATIVE_RELEASE_SUMMARY (Player\d+) side=(\d+) ownBlue=(\d+) enemyRed=(\d+) errors=(\d+) volume=([.\d]+) fps=([.\d]+)')
    audio=re.compile(r'KINGDOMS_NATIVE_AUDIO (Player\d+) (\w+) loaded=(true|false) (rbxassetid://\d+)')
    for file in sorted(LOGS.glob('*20261006T1040*Studio*last.log')):
        for line in file.read_text(encoding='utf8',errors='replace').splitlines():
            m=summary.search(line)
            if m:
                name,side,own,enemy,errors,volume,fps=m.groups()
                players[name]={'log':str(file),'viewerSide':int(side),'ownBlue':int(own),'enemyRed':int(enemy),'colourErrors':int(errors),'localEffectsVolume':float(volume),'fps':float(fps),'audio':{}}
            m=audio.search(line)
            if m and m[1]in players:players[m[1]]['audio'][m[2]]={'loaded':m[3]=='true','id':m[4]}
    assert len(players)==2
    assert all(p['ownBlue']>0 and p['enemyRed']>0 and p['colourErrors']==0 and len(p['audio'])==10 and all(a['loaded']for a in p['audio'].values())for p in players.values())
    assert players['Player1']['localEffectsVolume']==.173 and players['Player2']['localEffectsVolume']==.55
    report={'nativeStudio':True,'twoRealClients':True,'players':players,
        'fpsContext':'Player2 was the active window; Studio throttled the background Player1 window.',
        'originalAudioAllLoaded':True,'localVolumeIsolation':True,
        'tutorialSelectSendCapture':'Observed in the native AI session; all three steps completed.',
        'editorPlaceUndo':'Observed native actions; no full scene rebuild was required.',
        'mobile':'iPhone XR 896 x 414 simulator; menu and collection page inspected, shop height increased.',
        'realRobuxPaymentTested':False,'publishedDataStoreRejoinTested':False,
        'temporaryProbeArchivedDisabled':True}
    output=ROOT/'build/release/native-release-qa.json';output.write_text(json.dumps(report,indent=2),encoding='utf8')
    print(output)

if __name__=='__main__':main()
