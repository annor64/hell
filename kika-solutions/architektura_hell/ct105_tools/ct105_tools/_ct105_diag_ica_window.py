"""Diagnose Citrix ICA launch mode and current window classes on CT105."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo ICA_WINDOW_DIAG_BEGIN

echo "=== ICA FILES ==="
ls -lt /root/Downloads/*.ica /root/Downloads/*.ICA 2>/dev/null | sed -n '1,10p' || true

LATEST="$(ls -t /root/Downloads/*.ica /root/Downloads/*.ICA 2>/dev/null | head -n 1)"
echo "LATEST:$LATEST"

if [ -n "$LATEST" ]; then
  echo "=== ICA CONTENT (first 260 lines) ==="
  sed -n '1,260p' "$LATEST"
fi

echo "=== WINDOWS (wmctrl -lx) ==="
wmctrl -lx 2>/dev/null | sed -n '1,120p' || true

echo ICA_WINDOW_DIAG_END
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(hostname=HOST, username=USER, password=PASSWORD, timeout=25, look_for_keys=False, allow_agent=False)
stdin, stdout, stderr = client.exec_command(REMOTE_SCRIPT, get_pty=True)
print(stdout.read().decode("utf-8", errors="replace"))
err = stderr.read().decode("utf-8", errors="replace")
if err.strip():
    print("--- STDERR ---")
    print(err)
client.close()
