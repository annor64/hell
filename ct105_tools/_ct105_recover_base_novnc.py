"""Recover base TightVNC/noVNC stack and regenerate profile entry pages."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo RECOVER_BASE_BEGIN

echo --- status before ---
systemctl is-active tightvncserver@1.service || true
systemctl is-active novnc.service || true
systemctl status --no-pager tightvncserver@1.service | sed -n '1,120p' || true
systemctl status --no-pager novnc.service | sed -n '1,120p' || true
journalctl -u tightvncserver@1.service -n 80 --no-pager || true
journalctl -u novnc.service -n 80 --no-pager || true

mkdir -p /root/.vnc
cat > /root/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xrdb "$HOME/.Xresources"
startxfce4 &
EOF
chmod +x /root/.vnc/xstartup

if [ ! -f /root/.vnc/passwd ]; then
  printf 'artanox\nartanox\nn\n' | vncpasswd /root/.vnc/passwd >/dev/null 2>&1 || true
fi
chmod 600 /root/.vnc/passwd 2>/dev/null || true

# Dedicated resilient base VNC service (:1 -> 3200x1200)
cat > /etc/systemd/system/tightvncserver-base.service <<'UNIT'
[Unit]
Description=TightVNC Base Server on display :1
After=network.target

[Service]
Type=forking
User=root
PAMName=login
PIDFile=/root/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/tightvncserver -kill :1
ExecStartPre=-/usr/bin/pkill -f '^Xtightvnc :1'
ExecStartPre=-/bin/rm -f /root/.vnc/*:1.pid /tmp/.X1-lock /tmp/.X11-unix/X1
ExecStart=/usr/bin/tightvncserver :1 -geometry 3200x1200 -depth 24
ExecStop=/usr/bin/tightvncserver -kill :1
ExecStopPost=-/usr/bin/pkill -f '^Xtightvnc :1'
ExecStopPost=-/bin/rm -f /root/.vnc/*:1.pid /tmp/.X1-lock /tmp/.X11-unix/X1
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

# Dedicated resilient base noVNC service (8080 -> 5901)
cat > /etc/systemd/system/novnc-base.service <<'UNIT'
[Unit]
Description=noVNC Base WebSocket Proxy (8080 -> 5901)
After=network.target tightvncserver-base.service
Requires=tightvncserver-base.service

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 0.0.0.0:8080 127.0.0.1:5901
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

# Stop old brittle units if present
systemctl disable --now novnc.service 2>/dev/null || true
systemctl disable --now tightvncserver@1.service 2>/dev/null || true

systemctl daemon-reload || true
systemctl enable --now tightvncserver-base.service novnc-base.service || true
systemctl restart tightvncserver-base.service novnc-base.service || true

# Make profile pages independent (each profile points to its own noVNC port)
cat > /usr/share/novnc/vnc_fullhd.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC FullHD</title></head><body>
<script>window.location.replace('http://192.168.0.137:8082/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');</script>
<a href="#" onclick="location.replace('http://192.168.0.137:8082/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');return false;">Open FullHD noVNC</a>
</body></html>
EOF

cat > /usr/share/novnc/vnc_3200x1200.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC 3200x1200</title></head><body>
<script>window.location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');</script>
<a href="#" onclick="location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');return false;">Open 3200x1200 noVNC</a>
</body></html>
EOF

cat > /usr/share/novnc/vnc_browser.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC Browser</title></head><body>
<script>window.location.replace('http://192.168.0.137:8083/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');</script>
<a href="#" onclick="location.replace('http://192.168.0.137:8083/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');return false;">Open Browser noVNC</a>
</body></html>
EOF

cat > /usr/share/novnc/vnc_default.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC Default</title></head><body>
<script>window.location.replace('http://192.168.0.137:8083/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');</script>
<a href="#" onclick="location.replace('http://192.168.0.137:8083/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');return false;">Open Default noVNC</a>
</body></html>
EOF

cat > /usr/share/novnc/vnc_auto.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC Auto</title></head><body>
<script>
(function() {
  var w = Math.max(document.documentElement.clientWidth || 0, window.innerWidth || 0);
  if (w <= 2200) {
    window.location.replace('http://192.168.0.137:8083/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');
  } else if (w <= 3200) {
    window.location.replace('http://192.168.0.137:8082/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');
  } else {
    window.location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&quality=6&compression=2');
  }
})();
</script>
<a href="#" onclick="location.reload();return false;">Open Auto noVNC</a>
</body></html>
EOF

echo --- status after ---
for s in tightvncserver-base.service novnc-base.service tightvncserver-fullhd.service novnc-fullhd.service tightvncserver-browser.service novnc-browser.service; do
  printf '%s: ' "$s"
  systemctl is-active "$s" || true
done

ss -ltnp | grep -E ':5901|:5902|:5903|:8080|:8082|:8083' || true
ls -1 /usr/share/novnc | grep -E '^vnc_(auto|default|browser|fullhd|3200x1200)\.html$' | sort || true

echo URLS
echo AUTO:http://192.168.0.137:8080/vnc_auto.html
echo FULLHD:http://192.168.0.137:8082/vnc.html
echo BROWSER:http://192.168.0.137:8083/vnc.html
echo ULTRAWIDE:http://192.168.0.137:8080/vnc.html

echo RECOVER_BASE_END
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
