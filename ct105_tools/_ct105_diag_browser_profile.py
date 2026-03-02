"""Diagnose browser-friendly noVNC profile services (8083/5903)."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo BROWSER_DIAG_BEGIN
systemctl is-active tightvncserver-browser.service
systemctl is-active novnc-browser.service

echo --- status tightvncserver-browser ---
systemctl status --no-pager tightvncserver-browser.service | sed -n '1,120p'
echo --- logs tightvncserver-browser ---
journalctl -u tightvncserver-browser.service -n 120 --no-pager

echo --- status novnc-browser ---
systemctl status --no-pager novnc-browser.service | sed -n '1,120p'
echo --- logs novnc-browser ---
journalctl -u novnc-browser.service -n 120 --no-pager

echo --- ports ---
ss -ltnp | grep -E ':8083|:5903' || true

echo BROWSER_DIAG_END
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
