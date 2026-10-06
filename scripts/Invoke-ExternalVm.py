"""Pilote VIX de la VM dédiée ; secrets lus depuis work, jamais imprimés."""
import json, pathlib, subprocess, sys, os
ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = ROOT / 'work/phase-04/vm-externe'
VMRUN = r'C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe'
secret = json.loads((BASE/'credentials.json').read_text(encoding='utf-8-sig'))
operation = sys.argv[1]
vm=pathlib.Path(os.environ.get('BAGAGE_VM_VMX', str(BASE/'bagage-externe.vmx'))).resolve()
if not vm.is_relative_to(ROOT/'work'): raise RuntimeError('VM hors du dossier work')
args = [VMRUN, '-T', 'ws', '-gu', secret.get('username', 'bagagetest'), '-gp', secret['password'], operation, str(vm), *sys.argv[2:]]
result = subprocess.run(args, capture_output=True, text=True)
print((result.stdout + result.stderr).replace(secret['password'], '[secret]'), end='')
sys.exit(result.returncode)
