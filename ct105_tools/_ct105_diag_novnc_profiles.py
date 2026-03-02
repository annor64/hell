"""Deep health diagnostics for CT105 noVNC/TightVNC profiles and services."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo DIAG_BEGIN
systemctl is-active tightvncserver-base.service
systemctl is-active novnc-base.service
systemctl is-active tightvncserver-fullhd.service
systemctl is-active novnc-fullhd.service
systemctl is-active tightvncserver-browser.service
systemctl is-active novnc-browser.service

echo --- status-base ---
systemctl status --no-pager tightvncserver-base.service | sed -n '1,80p'
echo --- logs-base ---
journalctl -u tightvncserver-base.service -n 80 --no-pager

echo --- status-novnc-base ---
systemctl status --no-pager novnc-base.service | sed -n '1,80p'
echo --- logs-novnc-base ---
journalctl -u novnc-base.service -n 80 --no-pager

echo --- status-fullhd ---
systemctl status --no-pager tightvncserver-fullhd.service | sed -n '1,80p'
echo --- logs-fullhd ---
journalctl -u tightvncserver-fullhd.service -n 80 --no-pager

echo --- status-novnc-fullhd ---
systemctl status --no-pager novnc-fullhd.service | sed -n '1,80p'
echo --- logs-novnc-fullhd ---
journalctl -u novnc-fullhd.service -n 80 --no-pager

echo --- status-browser ---
systemctl status --no-pager tightvncserver-browser.service | sed -n '1,80p'
echo --- logs-browser ---
journalctl -u tightvncserver-browser.service -n 80 --no-pager

echo --- status-novnc-browser ---
systemctl status --no-pager novnc-browser.service | sed -n '1,80p'
echo --- logs-novnc-browser ---
journalctl -u novnc-browser.service -n 80 --no-pager

echo --- ports ---
ss -ltnp | grep -E ':8080|:8082|:8083|:5901|:5902|:5903' || true

echo --- novnc entries ---
ls -1 /usr/share/novnc | grep -E '^vnc_.*\\.html$' || true
for f in /usr/share/novnc/vnc_fullhd.html /usr/share/novnc/vnc_3200x1200.html /usr/share/novnc/vnc_browser.html /usr/share/novnc/vnc_auto.html /usr/share/novnc/vnc_default.html; do
  if [ -f "$f" ]; then
    echo "--- $f ---"
    sed -n '1,80p' "$f"
  fi
done

echo DIAG_END
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
