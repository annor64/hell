"""Repair xRDP listener port and keep resize-related options enabled."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo XRDP_PORT_FIX_BEGIN

python3 - <<'PY'
from pathlib import Path
p = Path('/etc/xrdp/xrdp.ini')
text = p.read_text(encoding='utf-8', errors='ignore').splitlines()
out = []
in_globals = False
for line in text:
    s = line.strip()
    if s.startswith('[') and s.endswith(']'):
        in_globals = (s.lower() == '[globals]')
        out.append(line)
        continue
    if in_globals and s.startswith('port='):
        out.append('port=3389')
        in_globals = False
        continue
    out.append(line)
p.write_text('\n'.join(out) + '\n', encoding='utf-8')
PY

# Ensure channels and options helpful for resize/scaling are present
if ! grep -q '^allow_multimon=' /etc/xrdp/xrdp.ini; then echo 'allow_multimon=true' >> /etc/xrdp/xrdp.ini; else sed -i 's/^allow_multimon=.*/allow_multimon=true/' /etc/xrdp/xrdp.ini; fi
if ! grep -q '^allow_channels=' /etc/xrdp/xrdp.ini; then echo 'allow_channels=true' >> /etc/xrdp/xrdp.ini; else sed -i 's/^allow_channels=.*/allow_channels=true/' /etc/xrdp/xrdp.ini; fi
if ! grep -q '^max_bpp=' /etc/xrdp/xrdp.ini; then echo 'max_bpp=32' >> /etc/xrdp/xrdp.ini; else sed -i 's/^max_bpp=.*/max_bpp=32/' /etc/xrdp/xrdp.ini; fi

systemctl restart xrdp xrdp-sesman
sleep 1

echo STATUS
systemctl is-active xrdp || true
systemctl is-active xrdp-sesman || true

echo LISTEN
ss -ltnp | grep ':3389' || true

echo CHECK
awk 'BEGIN{show=0} /^\[Globals\]/{show=1} /^\[/{if($0!="[Globals]") show=0} {if(show) print}' /etc/xrdp/xrdp.ini | sed -n '1,60p'

echo XRDP_PORT_FIX_END
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(hostname=HOST, username=USER, password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
stdin, stdout, stderr = client.exec_command(REMOTE_SCRIPT, get_pty=True)
print(stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err.strip():
    print('--- STDERR ---')
    print(err)
client.close()
