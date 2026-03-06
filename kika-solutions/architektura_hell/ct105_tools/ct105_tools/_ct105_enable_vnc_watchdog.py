"""Install a lightweight watchdog on CT105 to auto-heal noVNC on port 8080."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo VNC_WATCHDOG_BEGIN

cat > /usr/local/sbin/ct105-vnc-watchdog.sh <<'EOF'
#!/bin/sh
set -e

# Expected services and port mapping
BASE_VNC_SERVICE="tightvncserver-base.service"
BASE_NOVNC_SERVICE="novnc-base.service"

# If either service is not active, restart both.
if ! systemctl is-active --quiet "$BASE_VNC_SERVICE"; then
  systemctl restart "$BASE_VNC_SERVICE" "$BASE_NOVNC_SERVICE" || true
  exit 0
fi

if ! systemctl is-active --quiet "$BASE_NOVNC_SERVICE"; then
  systemctl restart "$BASE_VNC_SERVICE" "$BASE_NOVNC_SERVICE" || true
  exit 0
fi

# If port 8080 is not listening, restart noVNC side.
if ! ss -ltn '( sport = :8080 )' | grep -q ':8080'; then
  systemctl restart "$BASE_NOVNC_SERVICE" || true
fi
EOF
chmod 755 /usr/local/sbin/ct105-vnc-watchdog.sh

cat > /etc/systemd/system/ct105-vnc-watchdog.service <<'UNIT'
[Unit]
Description=CT105 noVNC watchdog (auto-heal 8080)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ct105-vnc-watchdog.sh
UNIT

cat > /etc/systemd/system/ct105-vnc-watchdog.timer <<'UNIT'
[Unit]
Description=Run CT105 noVNC watchdog every minute

[Timer]
OnBootSec=30s
OnUnitActiveSec=60s
AccuracySec=5s
Persistent=true

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now ct105-vnc-watchdog.timer
systemctl start ct105-vnc-watchdog.service

echo STATUS
systemctl is-active ct105-vnc-watchdog.timer || true
systemctl status --no-pager ct105-vnc-watchdog.timer | sed -n '1,60p' || true
systemctl status --no-pager ct105-vnc-watchdog.service | sed -n '1,80p' || true

echo VNC_SERVICES
systemctl is-active tightvncserver-base.service || true
systemctl is-active novnc-base.service || true
ss -ltnp | grep -E ':5901|:8080' || true

echo VNC_WATCHDOG_END
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
