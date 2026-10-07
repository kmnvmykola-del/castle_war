"""Save the native asset and facing check reported by the actual Roblox client."""
from pathlib import Path
import argparse
import json

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('log',type=Path)
args=parser.parse_args()
marker='KINGDOMS_NATIVE_PREMIUM_QA '
records=[json.loads(line.split(marker,1)[1])for line in args.log.read_text(encoding='utf8',errors='replace').splitlines()if marker in line and line.split(marker,1)[1].startswith('{')]
assert records,'No completed native premium check'
report=records[-1]
assert report['NativeStudio'] and report['Version']=='0.16'and report['MeshParts']==1969
assert not report['Failures'] and report['LoadedAssets']>0
assert set(report['Skins'])=={'Storm','Dragon','Oracle'}
for skin in report['Skins'].values():
    assert skin['Blue']==skin['Red']==4 and skin['HeadingChecks']==skin['Units']==8
report['Log']=str(args.log.resolve())
output=ROOT/'build/release/native-premium-qa.json'
output.write_text(json.dumps(report,indent=2),encoding='utf8')
print(output)
