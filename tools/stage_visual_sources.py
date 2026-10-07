"""Produce a guarded Studio command; native execution is separate."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
names=('Art','Config','Scene','CollectionUI','MetaUI','UI')
lines=["assert(not game:GetService('RunService'):IsRunning(),'Stop Play first'); local root=game:GetService('ReplicatedStorage').Kingdoms; local changes={}"]
for name in names:
    source=(ROOT/f'src/{name}.luau').read_text(encoding='utf8')
    assert ']====]'not in source
    lines.append(f"do local old=root:FindFirstChild('{name}');assert(old and old:IsA('ModuleScript'));local copy=old:Clone();copy.Source=[====[{source}]====];table.insert(changes,{{Old=old,Copy=copy}})end")
lines.append("local backup=Instance.new('Folder');backup.Name='KingdomsBeforeFacingFix_'..game:GetService('HttpService'):GenerateGUID(false);backup.Parent=game:GetService('ServerStorage');for _,c in changes do c.Old.Parent=backup;c.Copy.Parent=root end; if workspace:FindFirstChild('KingdomsVisualProof')then workspace.KingdomsVisualProof.Parent=backup end;print('KINGDOMS_FACING_FIX_INSTALLED',#changes)")
(ROOT/'build/release/install-facing-command.luau').write_text('\n'.join(lines),encoding='utf8')
print('Facing command staged:',len('\n'.join(lines)),'characters')
