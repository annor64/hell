"""Install and configure xRDP + XFCE on CT105.

This script is intended to be idempotent and safe to re-run.
"""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e
export DEBIAN_FRONTEND=noninteractive

echo XRDP_SETUP_BEGIN

apt-get update
apt-get install -y xrdp xorgxrdp xfce4 xfce4-goodies dbus-x11

# Prefer XFCE for xrdp sessions
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec startxfce4
EOF
chmod +x /etc/xrdp/startwm.sh

# Also set skeleton for non-root users just in case
mkdir -p /root
cat > /root/.xsession <<'EOF'
startxfce4
EOF
chmod 644 /root/.xsession

# Make sure xrdp can read cert key on Debian systems
adduser xrdp ssl-cert >/dev/null 2>&1 || true

systemctl daemon-reload
systemctl enable --now xrdp xrdp-sesman
systemctl restart xrdp xrdp-sesman

echo STATUS
systemctl is-active xrdp || true
systemctl is-active xrdp-sesman || true

echo PORT
ss -ltnp | grep ':3389' || true

echo CONF
grep -E '^(port=|security_layer=|crypt_level=)' /etc/xrdp/xrdp.ini || true

echo XRDP_SETUP_END
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
