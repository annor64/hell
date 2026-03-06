"""Configure noVNC on port 8080 with FullHD-oriented base VNC session and menu launcher."""

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

# Keep all common launcher pages as a menu on 8080
for f in index.html vnc.html vnc_auto.html vnc_default.html vnc_fullhd.html vnc_browser.html vnc_3200x1200.html; do
  cat > "/usr/share/novnc/$f" <<'EOF'
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>CT105 Remote Access (8080)</title>
</head>
<body style="font-family:Segoe UI,Arial,sans-serif;max-width:820px;margin:24px auto;line-height:1.5;">
  <h2 style="margin:0 0 12px;">CT105 remote access</h2>
  <p style="margin:0 0 16px;">Vyber přístup přes web noVNC nebo nativní VNC klient.</p>
  <ul>
    <li><a href="/vnc_lite.html?autoconnect=true&resize=scale&reconnect=true&path=websockify">noVNC (auto connect, scale)</a></li>
    <li><a href="/vnc_lite.html?resize=remote&reconnect=true&path=websockify">noVNC (manual / remote resize)</a></li>
    <li><a href="vnc://192.168.0.137:5901">TightVNC (native klient, port 5901)</a></li>
  </ul>
  <p style="margin-top:14px;">Když odkaz <b>vnc://</b> nejde kliknout v browseru, použij v klientovi adresu <b>192.168.0.137:5901</b>.</p>
</body>
</html>
EOF
done

systemctl daemon-reload
systemctl enable --now tightvncserver-base.service novnc-base.service >/dev/null 2>&1 || true
systemctl restart tightvncserver-base.service novnc-base.service

echo STATUS
systemctl is-active tightvncserver-base.service || true
systemctl is-active novnc-base.service || true

echo PORTS
ss -ltnp | grep -E ':5901|:8080' || true

echo URL
echo MENU:http://192.168.0.137:8080/
echo NOVNC_AUTO:http://192.168.0.137:8080/vnc_lite.html?autoconnect=true\&resize=scale\&reconnect=true\&path=websockify
echo TIGHTVNC_NATIVE:192.168.0.137:5901

echo VNC_8080_FULLSCREEN_END
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
