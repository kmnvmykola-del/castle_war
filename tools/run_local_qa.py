"""Compile all game sources and run deterministic server and UI smoke checks.

Uses the official Luau CLI in build/luau. Roblox services are simulated; this
does not replace a Studio render test, published DataStore or real Robux tests.
"""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
CLI = BUILD / 'luau/luau.exe'
COMPILER = BUILD / 'luau/luau-compile.exe'


def main():
    files = sorted((ROOT / 'src').rglob('*.luau'))
    for start in range(0, len(files), 35):
        result = subprocess.run([str(COMPILER), '--null', *map(str, files[start:start+35])], capture_output=True, text=True, encoding='utf8')
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
    header = (ROOT / 'tools/qa_cli_environment.luau').read_text(encoding='utf8')
    parts = [header]
    for path in sorted((ROOT / 'src').glob('*.luau')):
        name = path.name.removesuffix('.luau').removesuffix('.server').removesuffix('.client')
        if name in ('Server', 'Client'):
            continue
        parts.append(f"factories['{name}']=function(script,require)\n{path.read_text(encoding='utf8')}\nend\nlocal mod=Instance.new('ModuleScript');mod.Name='{name}';mod.Parent=root\n")
    parts.append("local geometry=Instance.new('Folder');geometry.Name='Geometry';geometry.Parent=root\n")
    for path in sorted((ROOT / 'src/Geometry').glob('*.luau')):
        parts.append(f"do local asset=Instance.new('ModuleScript');asset.Name='{path.stem}';asset.Parent=root.Geometry end\n")
    parts.append((ROOT / 'tools/qa_static_templates.luau').read_text(encoding='utf8'))
    parts.append("factories['Installer']=function(script,require)\n" + (ROOT / 'tools/install_static_meshes.luau').read_text(encoding='utf8') + "\nend\n")
    parts.append("factories['NeutralInstaller']=function(script,require)\n" + (ROOT / 'tools/install_neutral_meshes.luau').read_text(encoding='utf8') + "\nend\n")
    parts.append("factories['ReleaseInstaller']=function(script,require)\n" + (ROOT / 'tools/install_release.luau').read_text(encoding='utf8') + "\nend\n")
    parts.append("factories['PremiumInstaller']=function(script,require)\n" + (ROOT / 'tools/install_premium_v016.luau').read_text(encoding='utf8') + "\nend\n")
    report = {'compiled': len(files), 'suites': {}, 'studioRenderVerified': False}
    for name in ('qa_v011', 'qa_inventory', 'qa_inventory_ui', 'qa_english_ui', 'qa_editor_performance', 'qa_team_audio', 'qa_static_install', 'qa_neutral_install', 'qa_battle_guide', 'qa_release_install', 'qa_premium_install'):
        suite = ROOT / f'tools/{name}.luau'
        if not suite.exists():
            continue
        text = '\n'.join(parts) + '\nlocal report=(function()\n' + suite.read_text(encoding='utf8') + '\nend)()\n'
        text += "for name,c in report.cases do print(c.passed and 'PASS' or 'FAIL',name,c.passed and '' or tostring(c.result))end\nprint('QA_REPORT',report.passed,report.failed)\nassert(report.failed==0,'QA failures')\n"
        generated = BUILD / (name + '-local.luau')
        generated.write_text(text, encoding='utf8')
        result = subprocess.run([str(CLI), str(generated)], capture_output=True, text=True, encoding='utf8', timeout=90)
        (BUILD / (name + '-output.txt')).write_text(result.stdout + result.stderr, encoding='utf8')
        print(result.stdout, end='')
        if result.returncode:
            raise RuntimeError(result.stderr or 'QA failed')
        summary = next(line for line in result.stdout.splitlines() if line.startswith('QA_REPORT')).split()
        report['suites'][name] = {'passed': int(summary[1]), 'failed': int(summary[2])}
    (BUILD / 'inventory-qa-report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
