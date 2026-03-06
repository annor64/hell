"""Diagnose CT105 Citrix launch path (wfica process, connections, logs)."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo CITRIX_LAUNCH_DIAG_BEGIN

echo "=== PROCESSES ==="
pgrep -a -f '/opt/Citrix/ICAClient/wfica|selfservice|AuthManagerDaemon|ServiceRecord' || true

echo "=== CONNECTIONS (wfica) ==="
ss -tpn | grep -i wfica || true

echo "=== DOWNLOADS (.ica) ==="
find /root/Downloads -maxdepth 1 -type f \( -name '*.ica' -o -name '*.ICA' -o -name '*.crdownload' -o -name '*.part' \) -printf '%TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null | tail -n 40 || true

echo "=== WATCHER ==="
pgrep -a -f ct105-ica-autostart.sh || true
sed -n '1,220p' /tmp/ct105-ica-autostart.log 2>/dev/null || true

echo "=== CLIENT FILES ==="
find /root/.ICAClient -maxdepth 4 -type f 2>/dev/null | sed -n '1,200p' || true

echo "=== CLIENT LOGS ==="
for f in /root/.ICAClient/*.log /root/.ICAClient/*/*.log /root/.ICAClient/*/*/*.log /tmp/*wfica*.log /tmp/*ica*.log; do
  [ -f "$f" ] || continue
  echo "--- $f ---"
  sed -n '1,220p' "$f" || true
done

echo "=== WFCLIENT INI ==="
sed -n '1,220p' /root/.ICAClient/wfclient.ini 2>/dev/null || true

echo CITRIX_LAUNCH_DIAG_END
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
