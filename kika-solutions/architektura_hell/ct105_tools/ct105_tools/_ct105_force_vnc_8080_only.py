"""Force CT105 noVNC profiles into 8080-only mode with a clickable launcher menu."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo VNC_8080_ONLY_BEGIN

# Keep only base VNC/noVNC services enabled for web access
systemctl disable --now novnc-fullhd.service novnc-browser.service 2>/dev/null || true
systemctl disable --now tightvncserver-fullhd.service tightvncserver-browser.service 2>/dev/null || true

# Ensure base services exist and are running
systemctl enable --now tightvncserver-base.service novnc-base.service 2>/dev/null || true
systemctl restart tightvncserver-base.service novnc-base.service || true

# Overwrite launcher pages with a simple 8080 menu (no redirect loops)
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

# Trigger watchdog once now
systemctl start ct105-vnc-watchdog.service 2>/dev/null || true

echo STATUS
for s in tightvncserver-base.service novnc-base.service tightvncserver-fullhd.service novnc-fullhd.service tightvncserver-browser.service novnc-browser.service; do
  printf '%s: ' "$s"
  systemctl is-active "$s" || true
done

echo PORTS
ss -ltnp | grep -E ':5901|:8080|:8082|:8083' || true

echo CONTENT_CHECK
for f in /usr/share/novnc/index.html /usr/share/novnc/vnc.html /usr/share/novnc/vnc_auto.html /usr/share/novnc/vnc_default.html; do
  echo FILE:$f
  grep -Eo 'vnc_lite\.html|vnc://192\.168\.0\.137:5901|192\.168\.0\.137:[0-9]+' "$f" || true
done

echo URL
echo MENU:http://192.168.0.137:8080/
echo NOVNC_AUTO:http://192.168.0.137:8080/vnc_lite.html?autoconnect=true\&resize=scale\&reconnect=true\&path=websockify
echo TIGHTVNC_NATIVE:192.168.0.137:5901

echo VNC_8080_ONLY_END
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(hostname=HOST, username=USER, password=PASSWORD, timeout=20, look_for_keys=False, allow_agent=False)
stdin, stdout, stderr = client.exec_command(REMOTE_SCRIPT, get_pty=True)
print(stdout.read().decode("utf-8", errors="replace"))
err = stderr.read().decode("utf-8", errors="replace")
if err.strip():
    print("--- STDERR ---")
    print(err)
client.close()
