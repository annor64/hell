"""Diagnose CT105 Cisco VPN + Citrix DNS/proxy/browser profile state."""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo VPN_DNS_DIAG_BEGIN

echo === VPN STATE ===
ls -l /opt/cisco/secureclient/bin/vpn 2>/dev/null || true
/opt/cisco/secureclient/bin/vpn state 2>&1 || true
systemctl is-active vpnagentd 2>/dev/null || true

echo === DNS BASE ===
grep -n '^nameserver' /etc/resolv.conf || true

echo "=== DNS LOOKUP apps.cez.cz ==="
nslookup apps.cez.cz 2>&1 || true
echo --- via 172.30.202.10 ---
nslookup apps.cez.cz 172.30.202.10 2>&1 || true
echo --- via 172.20.202.10 ---
nslookup apps.cez.cz 172.20.202.10 2>&1 || true

echo === ROUTES ===
ip route | sed -n '1,80p' || true

echo === FIREFOX PROFILES ===
ls -la /root/.mozilla/firefox 2>/dev/null || true
echo --- profiles.ini ---
sed -n '1,220p' /root/.mozilla/firefox/profiles.ini 2>/dev/null || true

echo "=== FIREFOX PREFS proxy kerberos trr ==="
for p in /root/.mozilla/firefox/*; do
  [ -f "$p/prefs.js" ] || continue
  echo "--- $p/prefs.js ---"
  grep -E 'network\.proxy\.|network\.trr|signon\.autologin\.proxy|network\.automatic-ntlm-auth\.trusted-uris|network\.negotiate-auth\.trusted-uris' "$p/prefs.js" | sed -n '1,220p' || true
done

echo === URL TEST ===
curl -I -k -m 12 https://apps.cez.cz/Citrix/CEZWeb/ 2>&1 | sed -n '1,40p' || true

echo VPN_DNS_DIAG_END
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
