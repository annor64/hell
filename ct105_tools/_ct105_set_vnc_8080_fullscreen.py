"""Configure noVNC on port 8080 with FullHD-oriented base VNC session."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo VNC_8080_FULLSCREEN_BEGIN

# Keep primary VNC on :1 with FullHD geometry
cat > /etc/systemd/system/tightvncserver-base.service <<'UNIT'
[Unit]
Description=TightVNC Base Server on display :1 (FullHD)
After=network.target

[Service]
Type=forking
User=root
PAMName=login
PIDFile=/root/.vnc/%H:1.pid
ExecStartPre=-/usr/bin/tightvncserver -kill :1
ExecStartPre=-/usr/bin/pkill -f '^Xtightvnc :1'
ExecStartPre=-/bin/rm -f /root/.vnc/*:1.pid /tmp/.X1-lock /tmp/.X11-unix/X1
ExecStart=/usr/bin/tightvncserver :1 -geometry 1920x1080 -depth 24
ExecStop=/usr/bin/tightvncserver -kill :1
ExecStopPost=-/usr/bin/pkill -f '^Xtightvnc :1'
ExecStopPost=-/bin/rm -f /root/.vnc/*:1.pid /tmp/.X1-lock /tmp/.X11-unix/X1
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

# Ensure noVNC base endpoint on 8080 -> 5901
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

# Make 8080 profile pages all point to fullscreen-friendly base endpoint
cat > /usr/share/novnc/vnc_auto.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC Auto</title></head><body>
<script>window.location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true');</script>
<a href="#" onclick="location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true');return false;">Open noVNC</a>
</body></html>
EOF

cat > /usr/share/novnc/vnc_default.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC Default</title></head><body>
<script>window.location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true');</script>
<a href="#" onclick="location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true');return false;">Open noVNC</a>
</body></html>
EOF

cat > /usr/share/novnc/vnc_fullhd.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC FullHD</title></head><body>
<script>window.location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true');</script>
<a href="#" onclick="location.replace('http://192.168.0.137:8080/vnc.html?autoconnect=true&resize=scale&reconnect=true');return false;">Open noVNC FullHD</a>
</body></html>
EOF

# Friendly index page on /
cat > /usr/share/novnc/index.html <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>noVNC 8080</title></head><body>
<script>window.location.replace('/vnc.html?autoconnect=true&resize=scale&reconnect=true');</script>
<a href="/vnc.html?autoconnect=true&resize=scale&reconnect=true">Open noVNC</a>
</body></html>
EOF

systemctl daemon-reload
systemctl enable --now tightvncserver-base.service novnc-base.service >/dev/null 2>&1 || true
systemctl restart tightvncserver-base.service novnc-base.service

echo STATUS
systemctl is-active tightvncserver-base.service || true
systemctl is-active novnc-base.service || true

echo PORTS
ss -ltnp | grep -E ':5901|:8080' || true

echo URL
echo MAIN:http://192.168.0.137:8080/vnc.html?autoconnect=true\&resize=scale\&reconnect=true

echo VNC_8080_FULLSCREEN_END
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
