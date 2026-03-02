"""Collect xRDP config/log diagnostics focused on resize behavior."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo XRDP_RESIZE_DIAG_BEGIN

echo --- Xorg section ---
awk 'BEGIN{s=0} /^\[/{s=0} /^\[Xorg\]/{s=1} {if(s)print}' /etc/xrdp/xrdp.ini | sed -n '1,120p'

echo --- Globals section ---
awk 'BEGIN{s=0} /^\[Globals\]/{s=1;next} /^\[/{if(s){exit}} {if(s)print}' /etc/xrdp/xrdp.ini | sed -n '1,120p'

echo --- xrdp.log (resize hints) ---
grep -Ei 'display|monitor|resize|randr|chansrv|geometry|resolution' /var/log/xrdp.log | tail -n 120 || true

echo --- xrdp-sesman.log (resize hints) ---
grep -Ei 'display|monitor|resize|randr|geometry|resolution|xorgxrdp' /var/log/xrdp-sesman.log | tail -n 120 || true

echo --- ports ---
ss -ltnp | grep -E ':3389' || true

echo XRDP_RESIZE_DIAG_END
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(hostname=HOST, username=USER, password=PASSWORD, timeout=20, look_for_keys=False, allow_agent=False)
stdin, stdout, stderr = client.exec_command(REMOTE_SCRIPT, get_pty=True)
print(stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err.strip():
    print('--- STDERR ---')
    print(err)
client.close()
