"""Set RDP-first desktop workflow and Citrix launchers on CT105."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo RDP_CITRIX_DEFAULT_BEGIN

# Ensure xRDP stays primary and persistent
systemctl enable --now xrdp xrdp-sesman >/dev/null 2>&1 || true

# Ensure XFCE session for root in RDP
cat > /root/.xsession <<'EOF'
startxfce4
EOF
chmod 644 /root/.xsession

mkdir -p /root/Desktop

# 1) Citrix Workspace app launcher
cat > /root/Desktop/01_Citrix_Workspace.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Citrix Workspace
Comment=Open Citrix Workspace app
Exec=/opt/Citrix/ICAClient/selfservice --icaroot /opt/Citrix/ICAClient
Icon=applications-internet
Terminal=false
Categories=Network;
EOF
chmod +x /root/Desktop/01_Citrix_Workspace.desktop

# 2) Citrix Web launcher (fallback)
cat > /root/Desktop/02_Citrix_Web.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Citrix Web Login
Comment=Open Citrix web login page
Exec=firefox --new-window "https://apps.cez.cz/Citrix/CEZWeb/"
Icon=web-browser
Terminal=false
Categories=Network;
EOF
chmod +x /root/Desktop/02_Citrix_Web.desktop

# 3) Optional: helper note on desktop
cat > /root/Desktop/00_START_HERE.txt <<'EOF'
Doporuceny postup:
1) Pripojit se z Windows pres RDP (mstsc) na 192.168.0.137
2) Na plose spustit 01_Citrix_Workspace
3) Kdyz app login zlobi, pouzit 02_Citrix_Web
EOF

# Trust desktop launchers in XFCE
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="desktop-icons" type="empty">
    <property name="style" type="int" value="2"/>
    <property name="file-icons" type="empty">
      <property name="show-removable" type="bool" value="false"/>
      <property name="show-trash" type="bool" value="false"/>
    </property>
    <property name="icon-size" type="uint" value="48"/>
  </property>
</channel>
EOF

echo STATUS
systemctl is-active xrdp || true
systemctl is-active xrdp-sesman || true
ls -l /root/Desktop | sed -n '1,120p'

echo RDP_CITRIX_DEFAULT_END
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
