"""Configure CT105 for RDP Citrix-only workflow with Cisco VPN bootstrap.

Result:
- xRDP remains primary access method.
- For root RDP sessions, desktop is replaced by a Citrix-only launcher flow.
- Cisco VPN components are started first (when installed), then Citrix Web opens in browser.
  Browser-first is used because SSO/Kerberos flows are often better supported there.
"""

import paramiko

HOST = "192.168.0.137"
USER = "root"
PASSWORD = "artanox"

REMOTE_SCRIPT = r'''
set +e

echo RDP_CITRIX_VPN_ONLY_BEGIN

systemctl enable --now xrdp xrdp-sesman >/dev/null 2>&1 || true
apt-get update >/dev/null 2>&1 || true
apt-get install -y wmctrl xdotool autocutsel xclip >/dev/null 2>&1 || true
apt-get install -y xfwm4 xfconf >/dev/null 2>&1 || true

# Ensure xRDP clipboard channel is enabled
if grep -q '^allow_channels=' /etc/xrdp/xrdp.ini; then
  sed -i 's/^allow_channels=.*/allow_channels=true/' /etc/xrdp/xrdp.ini
else
  echo 'allow_channels=true' >> /etc/xrdp/xrdp.ini
fi

if grep -q '^\[Channels\]' /etc/xrdp/xrdp.ini; then
  sed -i 's/^cliprdr=.*/cliprdr=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
  sed -i 's/^rdpdr=.*/rdpdr=true/' /etc/xrdp/xrdp.ini 2>/dev/null || true
else
  cat >> /etc/xrdp/xrdp.ini <<'EOF'

[Channels]
rdpdr=true
rdpsnd=true
drdynvc=true
cliprdr=true
rail=true
xrdpvr=true
tcutils=true
EOF
fi

# Ensure sesman/chansrv clipboard path is explicitly enabled
python3 - <<'PY'
from pathlib import Path
p = Path('/etc/xrdp/sesman.ini')
text = p.read_text(encoding='utf-8', errors='ignore').splitlines()
out = []
in_chansrv = False
seen = set()

for line in text:
  stripped = line.strip()
  if stripped.startswith('[') and stripped.endswith(']'):
    if in_chansrv:
      if 'EnableClipboard' not in seen:
        out.append('EnableClipboard=true')
      if 'RestrictInboundClipboard' not in seen:
        out.append('RestrictInboundClipboard=none')
      if 'RestrictOutboundClipboard' not in seen:
        out.append('RestrictOutboundClipboard=none')
    in_chansrv = (stripped.lower() == '[chansrv]')
    seen = set()
    out.append(line)
    continue

  if in_chansrv and '=' in line and not stripped.startswith(';'):
    key = line.split('=', 1)[0].strip()
    key_l = key.lower()
    if key_l == 'enableclipboard':
      out.append('EnableClipboard=true')
      seen.add('EnableClipboard')
      continue
    if key_l == 'restrictinboundclipboard':
      out.append('RestrictInboundClipboard=none')
      seen.add('RestrictInboundClipboard')
      continue
    if key_l == 'restrictoutboundclipboard':
      out.append('RestrictOutboundClipboard=none')
      seen.add('RestrictOutboundClipboard')
      continue
  out.append(line)

if in_chansrv:
  if 'EnableClipboard' not in seen:
    out.append('EnableClipboard=true')
  if 'RestrictInboundClipboard' not in seen:
    out.append('RestrictInboundClipboard=none')
  if 'RestrictOutboundClipboard' not in seen:
    out.append('RestrictOutboundClipboard=none')

if not any(l.strip().lower() == '[chansrv]' for l in out):
  out.append('')
  out.append('[Chansrv]')
  out.append('EnableClipboard=true')
  out.append('RestrictInboundClipboard=none')
  out.append('RestrictOutboundClipboard=none')

p.write_text('\n'.join(out).rstrip() + '\n', encoding='utf-8')
print('SESMAN_CLIPBOARD_APPLIED')
PY

# Keep RDP session alive when client window is closed (disconnect != logoff)
python3 - <<'PY'
from pathlib import Path
p = Path('/etc/xrdp/sesman.ini')
lines = p.read_text(encoding='utf-8', errors='ignore').splitlines()
out = []
in_sessions = False
seen = set()

for line in lines:
  s = line.strip()
  if s.startswith('[') and s.endswith(']'):
    if in_sessions:
      if 'KillDisconnected' not in seen:
        out.append('KillDisconnected=false')
      if 'DisconnectedTimeLimit' not in seen:
        out.append('DisconnectedTimeLimit=0')
      if 'IdleTimeLimit' not in seen:
        out.append('IdleTimeLimit=0')
    in_sessions = (s.lower() == '[sessions]')
    seen = set()
    out.append(line)
    continue

  if in_sessions and '=' in line and not s.startswith(';'):
    key = line.split('=', 1)[0].strip().lower()
    if key == 'policy':
      out.append('Policy=U')
      seen.add('Policy')
      continue
    if key == 'killdisconnected':
      out.append('KillDisconnected=false')
      seen.add('KillDisconnected')
      continue
    if key == 'disconnectedtimelimit':
      out.append('DisconnectedTimeLimit=0')
      seen.add('DisconnectedTimeLimit')
      continue
    if key == 'idletimelimit':
      out.append('IdleTimeLimit=0')
      seen.add('IdleTimeLimit')
      continue

  out.append(line)

if in_sessions:
  if 'Policy' not in seen:
    out.append('Policy=U')
  if 'KillDisconnected' not in seen:
    out.append('KillDisconnected=false')
  if 'DisconnectedTimeLimit' not in seen:
    out.append('DisconnectedTimeLimit=0')
  if 'IdleTimeLimit' not in seen:
    out.append('IdleTimeLimit=0')

if not any(l.strip().lower() == '[sessions]' for l in out):
  out.append('')
  out.append('[Sessions]')
  out.append('Policy=U')
  out.append('KillDisconnected=false')
  out.append('DisconnectedTimeLimit=0')
  out.append('IdleTimeLimit=0')

p.write_text('\n'.join(out).rstrip() + '\n', encoding='utf-8')
print('SESMAN_SESSION_PERSISTENCE_APPLIED')
PY

# Pull StoreFront cert chain and install into system trust (helps AuthManager curlcode 60)
mkdir -p /usr/local/share/ca-certificates/cez-citrix
CHAIN_TMP=/tmp/ct105-citrix-chain.pem
if command -v openssl >/dev/null 2>&1; then
  echo | openssl s_client -showcerts -servername citrix.cezdata.corp -connect citrix.cezdata.corp:443 2>/dev/null > "$CHAIN_TMP" || true
  awk 'BEGIN{n=0;state=0} /BEGIN CERTIFICATE/{state=1;n++;fn=sprintf("/usr/local/share/ca-certificates/cez-citrix/citrix_cezdata_chain_%02d.crt",n)} {if(state) print > fn} /END CERTIFICATE/{if(state){close(fn);state=0}}' "$CHAIN_TMP" || true
fi
update-ca-certificates >/tmp/update-ca-certificates.log 2>&1 || true

# Sync system CA certs into Citrix ICAClient store (idempotent)
if [ -d /opt/Citrix/ICAClient/keystore/cacerts ] && [ -x /opt/Citrix/ICAClient/util/ctx_rehash ]; then
  find /opt/Citrix/ICAClient/keystore/cacerts -maxdepth 1 -type l -name '*.crt' -delete 2>/dev/null || true
  for cert in /usr/share/ca-certificates/mozilla/*.crt; do
    [ -e "$cert" ] || continue
    ln -sf "$cert" "/opt/Citrix/ICAClient/keystore/cacerts/$(basename "$cert")"
  done
  /opt/Citrix/ICAClient/util/ctx_rehash /opt/Citrix/ICAClient/keystore/cacerts >/dev/null 2>&1 || true
fi

# Keep backup once
if [ -f /etc/xrdp/startwm.sh ] && [ ! -f /etc/xrdp/startwm.sh.ct105.bak ]; then
  cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.ct105.bak
fi

cat > /usr/local/bin/ct105-citrix-vpn-session.sh <<'EOF'
#!/bin/sh
set +e

LOG=/tmp/ct105-citrix-vpn-session.log
CITRIX_WEB_URL="https://citrix.cezdata.corp/Citrix/CEZWeb/"
FIREFOX_PROFILE_DIR="/root/.mozilla/firefox/ct105-rdp-citrix"
if [ -d /root/.mozilla/firefox/relxe4el.default-esr ]; then
  FIREFOX_PROFILE_DIR="/root/.mozilla/firefox/relxe4el.default-esr"
fi
DOWNLOAD_DIR="/root/Downloads"
echo "===== $(date '+%F %T') SESSION START user=$USER =====" >> "$LOG"

# Ensure XFCE window manager is active in xRDP root session.
# Without xfwm4, windows can lose decorations (no resize handles), edge snapping,
# and moving windows may produce black repaint artifacts.
if command -v xfwm4 >/dev/null 2>&1; then
  if ! pgrep -x xfwm4 >/dev/null 2>&1; then
    xfwm4 --replace >/tmp/ct105-xfwm4.log 2>&1 &
    sleep 1
  fi
fi

# Apply WM behavior focused on RDP stability + window snapping.
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s false 2>/dev/null || xfconf-query -c xfwm4 -p /general/use_compositing -t bool -s false
  xfconf-query -c xfwm4 -p /general/box_move -n -t bool -s true 2>/dev/null || xfconf-query -c xfwm4 -p /general/box_move -t bool -s true
  xfconf-query -c xfwm4 -p /general/box_resize -n -t bool -s true 2>/dev/null || xfconf-query -c xfwm4 -p /general/box_resize -t bool -s true
  xfconf-query -c xfwm4 -p /general/snap_to_border -n -t bool -s true 2>/dev/null || xfconf-query -c xfwm4 -p /general/snap_to_border -t bool -s true
  xfconf-query -c xfwm4 -p /general/snap_to_windows -n -t bool -s true 2>/dev/null || xfconf-query -c xfwm4 -p /general/snap_to_windows -t bool -s true
  xfconf-query -c xfwm4 -p /general/snap_width -n -t int -s 20 2>/dev/null || xfconf-query -c xfwm4 -p /general/snap_width -t int -s 20
  xfconf-query -c xfwm4 -p /general/tile_on_move -n -t bool -s true 2>/dev/null || xfconf-query -c xfwm4 -p /general/tile_on_move -t bool -s true
fi

# Persist same settings directly to xfwm4 channel XML (reliable even without xfconfd bus)
mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
    <property name="box_move" type="bool" value="true"/>
    <property name="box_resize" type="bool" value="true"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="true"/>
    <property name="snap_width" type="int" value="20"/>
    <property name="tile_on_move" type="bool" value="true"/>
  </property>
</channel>
EOS

DESIRED_W=3200
DESIRED_H=1200

VPN_BIN=""
VPNUI_BIN=""

for c in \
  /opt/cisco/anyconnect/bin/vpn \
  /opt/cisco/secureclient/bin/vpn
do
  if [ -x "$c" ]; then VPN_BIN="$c"; break; fi
done

for c in \
  /opt/cisco/anyconnect/bin/vpnui \
  /opt/cisco/secureclient/bin/vpnui
do
  if [ -x "$c" ]; then VPNUI_BIN="$c"; break; fi
done

if systemctl list-unit-files 2>/dev/null | grep -q '^vpnagentd\.service'; then
  systemctl enable --now vpnagentd >/dev/null 2>&1 || true
fi

CONNECTED=0
if [ -n "$VPN_BIN" ]; then
  "$VPN_BIN" state 2>/dev/null | grep -Eqi 'state:\s*Connected|>> state:\s*Connected|Connected' && CONNECTED=1
fi

if [ "$CONNECTED" -eq 0 ] && [ -n "$VPNUI_BIN" ]; then
  "$VPNUI_BIN" >/dev/null 2>&1 &
  echo "vpnui launched" >> "$LOG"
fi

if [ "$CONNECTED" -eq 0 ] && [ -n "$VPN_BIN" ]; then
  n=0
  while [ $n -lt 60 ]; do
    "$VPN_BIN" state 2>/dev/null | grep -Eqi 'state:\s*Connected|>> state:\s*Connected|Connected' && CONNECTED=1 && break
    n=$((n+1))
    sleep 2
  done
fi

if [ "$CONNECTED" -eq 1 ]; then
  echo "vpn connected" >> "$LOG"
else
  echo "vpn not confirmed connected; continuing to Citrix" >> "$LOG"
fi

# Clipboard bridge: keep CLIPBOARD authoritative for xRDP inbound paste,
# mirror into PRIMARY so legacy/X11 apps can paste too.
pkill -f 'autocutsel' >/dev/null 2>&1 || true
autocutsel -selection CLIPBOARD -fork >/dev/null 2>&1 || true

mkdir -p "$DOWNLOAD_DIR"
mkdir -p /root/.ICAClient

python3 - <<PY
from pathlib import Path

wf = Path('/root/.ICAClient/wfclient.ini')
if wf.exists():
  lines = wf.read_text(encoding='utf-8', errors='ignore').splitlines()
else:
  lines = []

target = {
  'WFClient': {
    'KeyboardEventMode': 'Unicode',
    'MouseSendsControlV': 'True',
    'EnhancedResizingEnabled': 'True',
    'MultiMonitorPnPEnabled': 'False',
    'ClientClipboard': 'On'
  },
  'Thinwire3.0': {
    'DesiredHRES': '${DESIRED_W}',
    'DesiredVRES': '${DESIRED_H}',
    'DesiredColor': '32',
    'UseFullScreen': 'False'
  }
}

def normalize_key(s: str) -> str:
  return s.strip().lower()

section = None
seen = {k: set() for k in target}
out = []

for line in lines:
  stripped = line.strip()
  if stripped.startswith('[') and stripped.endswith(']'):
    if section in target:
      for k, v in target[section].items():
        if normalize_key(k) not in seen[section]:
          out.append(f'{k}={v}')
    section = stripped[1:-1]
    out.append(line)
    continue

  if section in target and '=' in line and not stripped.startswith(';'):
    k = line.split('=', 1)[0].strip()
    k_norm = normalize_key(k)
    matched = None
    for tk, tv in target[section].items():
      if normalize_key(tk) == k_norm:
        matched = (tk, tv)
        break
    if matched:
      seen[section].add(k_norm)
      out.append(f'{matched[0]}={matched[1]}')
      continue

  out.append(line)

for sec, kv in target.items():
  if not any(l.strip() == f'[{sec}]' for l in out):
    out.append(f'[{sec}]')
  if sec != section:
    pass

existing_sections = {}
current = None
for i, l in enumerate(out):
  s = l.strip()
  if s.startswith('[') and s.endswith(']'):
    current = s[1:-1]
    existing_sections.setdefault(current, i)

for sec, kv in target.items():
  if sec not in existing_sections:
    out.append(f'[{sec}]')
    existing_sections[sec] = len(out) - 1
    for k, v in kv.items():
      out.append(f'{k}={v}')
    continue

  sec_index = existing_sections[sec]
  next_sec_index = len(out)
  for idx in range(sec_index + 1, len(out)):
    s = out[idx].strip()
    if s.startswith('[') and s.endswith(']'):
      next_sec_index = idx
      break
  sec_block = out[sec_index + 1:next_sec_index]
  sec_keys = {normalize_key(x.split('=',1)[0].strip()) for x in sec_block if '=' in x and not x.strip().startswith(';')}
  inserts = [f'{k}={v}' for k, v in kv.items() if normalize_key(k) not in sec_keys]
  if inserts:
    out[next_sec_index:next_sec_index] = inserts

wf.write_text('\n'.join(out).rstrip() + '\n', encoding='utf-8')
print('WFCLIENT_RES_APPLIED')
PY

sed -i "s/^DesiredHRES[[:space:]]*=.*/DesiredHRES = ${DESIRED_W}/" /root/.ICAClient/wfclient.ini 2>/dev/null || true
sed -i "s/^DesiredVRES[[:space:]]*=.*/DesiredVRES = ${DESIRED_H}/" /root/.ICAClient/wfclient.ini 2>/dev/null || true
sed -i "s/^DesiredColor[[:space:]]*=.*/DesiredColor = 32/" /root/.ICAClient/wfclient.ini 2>/dev/null || true
sed -i "s/^UseFullScreen[[:space:]]*=.*/UseFullScreen=False/" /root/.ICAClient/wfclient.ini 2>/dev/null || true
sed -i "s/^EnhancedResizingEnabled[[:space:]]*=.*/EnhancedResizingEnabled=True/" /root/.ICAClient/wfclient.ini 2>/dev/null || true
sed -i "s/^ClientClipboard[[:space:]]*=.*/ClientClipboard=On/" /root/.ICAClient/wfclient.ini 2>/dev/null || true
grep -q '^ClientClipboard[[:space:]]*=' /root/.ICAClient/wfclient.ini || echo "ClientClipboard=On" >> /root/.ICAClient/wfclient.ini

# Prefer web ICA download path over receiver:// URL handlers
mkdir -p /root/.config
cat > /root/.config/mimeapps.list <<'EOS'
[Default Applications]
application/x-ica=wfica.desktop
application/ica=wfica.desktop
application/vnd.citrix.receiver.configure=new_store.desktop
EOS

cat > /usr/local/bin/ct105-ica-autostart.sh <<'EOS'
#!/bin/sh
set +e

DOWNLOAD_DIR="/root/Downloads"
LOG="/tmp/ct105-ica-autostart.log"
mkdir -p "$DOWNLOAD_DIR"

TARGET_W=3200
TARGET_H=1200

while true; do
  find "$DOWNLOAD_DIR" -maxdepth 1 -type f \( -name '*.ica' -o -name '*.ICA' \) | while IFS= read -r f; do
    [ -f "$f" ] || continue
    [ -f "$f.launched" ] && continue
    touch "$f.launched"

    sed -i "s/^DesiredHRES=.*/DesiredHRES=${TARGET_W}/" "$f" 2>/dev/null || true
    sed -i "s/^DesiredVRES=.*/DesiredVRES=${TARGET_H}/" "$f" 2>/dev/null || true
    sed -i "s/^DesiredColor=.*/DesiredColor=32/" "$f" 2>/dev/null || true
    sed -i "s/^ConnectionBar=.*/ConnectionBar=1/" "$f" 2>/dev/null || true
    sed -i "s/^TWIMode=.*/TWIMode=On/" "$f" 2>/dev/null || true
    sed -i "s/^ClientClipboard=.*/ClientClipboard=On/" "$f" 2>/dev/null || true
    sed -i "s/^ClipboardAllowed=.*/ClipboardAllowed=On/" "$f" 2>/dev/null || true

    grep -q '^DesiredHRES=' "$f" || echo "DesiredHRES=${TARGET_W}" >> "$f"
    grep -q '^DesiredVRES=' "$f" || echo "DesiredVRES=${TARGET_H}" >> "$f"
    grep -q '^DesiredColor=' "$f" || echo "DesiredColor=32" >> "$f"
    grep -q '^ConnectionBar=' "$f" || echo "ConnectionBar=1" >> "$f"
    grep -q '^TWIMode=' "$f" || echo "TWIMode=On" >> "$f"
    grep -q '^ClientClipboard=' "$f" || echo "ClientClipboard=On" >> "$f"
    grep -q '^ClipboardAllowed=' "$f" || echo "ClipboardAllowed=On" >> "$f"

    echo "$(date '+%F %T') launching ICA: $f" >> "$LOG"
    /opt/Citrix/ICAClient/wfica "$f" >/tmp/ct105-wfica.log 2>&1 &
  done
  sleep 1
done
EOS
chmod +x /usr/local/bin/ct105-ica-autostart.sh

pkill -f 'ct105-ica-autostart.sh' >/dev/null 2>&1 || true
/usr/local/bin/ct105-ica-autostart.sh >/dev/null 2>&1 &

if command -v firefox >/dev/null 2>&1; then
  mkdir -p "$FIREFOX_PROFILE_DIR"

  cat > "$FIREFOX_PROFILE_DIR/user.js" <<'EOS'
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "/root/Downloads");
user_pref("browser.download.always_ask_before_handling_new_types", false);
user_pref("browser.helperApps.neverAsk.openFile", "application/x-ica,application/ica,application/vnd.citrix.ica,application/x-ica;charset=utf-8");
user_pref("browser.helperApps.neverAsk.saveToDisk", "application/x-ica,application/ica,application/vnd.citrix.ica,application/x-ica;charset=utf-8");
user_pref("network.protocol-handler.external.receiver", false);
user_pref("network.protocol-handler.external.citrixapp", false);
user_pref("network.protocol-handler.external.ctxaadsso", false);
EOS

  if pgrep -u "$USER" -f "firefox.*ct105-rdp-citrix|/opt/Citrix/ICAClient/wfica|/opt/Citrix/ICAClient/selfservice" >/dev/null 2>&1; then
    echo "citrix/firefox already running; waiting and keeping session" >> "$LOG"
    exec sh -c 'while pgrep -u "$USER" -f "firefox.*ct105-rdp-citrix|/opt/Citrix/ICAClient/wfica|/opt/Citrix/ICAClient/selfservice" >/dev/null 2>&1; do sleep 5; done'
  fi

  exec firefox --no-remote --profile "$FIREFOX_PROFILE_DIR" --new-window "$CITRIX_WEB_URL"
fi

if command -v chromium >/dev/null 2>&1; then
  exec chromium "$CITRIX_WEB_URL"
fi

if command -v google-chrome >/dev/null 2>&1; then
  exec google-chrome "$CITRIX_WEB_URL"
fi

if [ -x /opt/Citrix/ICAClient/selfservice ]; then
  exec /opt/Citrix/ICAClient/selfservice --icaroot /opt/Citrix/ICAClient
fi

echo "Browser ani Citrix client nebyly nalezeny" >> "$LOG"
exec xterm -hold -e 'echo Firefox/Chromium ani Citrix client nenalezen; echo; read -p "Stiskni Enter pro ukonceni..."'
EOF
chmod +x /usr/local/bin/ct105-citrix-vpn-session.sh

cat > /usr/local/bin/ct105-rdp-entrypoint.sh <<'EOF'
#!/bin/sh
if [ "$USER" = "root" ]; then
  exec /usr/local/bin/ct105-citrix-vpn-session.sh
fi
exec startxfce4
EOF
chmod +x /usr/local/bin/ct105-rdp-entrypoint.sh

cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
  . /etc/default/locale
  export LANG LANGUAGE
fi
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec /usr/local/bin/ct105-rdp-entrypoint.sh
EOF
chmod +x /etc/xrdp/startwm.sh

mkdir -p /root/Desktop
mkdir -p /root/.config
cat > /root/.config/mimeapps.list <<'EOF'
[Default Applications]
application/x-ica=wfica.desktop
application/ica=wfica.desktop
application/vnd.citrix.receiver.configure=new_store.desktop
EOF

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

cat > /root/Desktop/02_Citrix_Web.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Citrix Web Login
Comment=Open Citrix web login page
Exec=firefox --new-window "https://citrix.cezdata.corp/Citrix/CEZWeb/"
Icon=web-browser
Terminal=false
Categories=Network;
EOF
chmod +x /root/Desktop/02_Citrix_Web.desktop

cat > /root/Desktop/00_MODE_INFO.txt <<'EOF'
CT105 je v rezimu: RDP -> Cisco VPN -> Citrix Web only.

Po RDP prihlaseni se nespousti bezna plocha, ale Citrix Web ve Firefoxu/browseru.
Pokud VPN neni pripojena, spusti se Cisco VPN UI pro prihlaseni.
Na plose zustavaji i dva launchery: 01_Citrix_Workspace a 02_Citrix_Web.
EOF

cat > /root/Desktop/90_DISABLE_CITRIX_ONLY.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Disable Citrix-only mode
Comment=Restore regular XFCE desktop for root RDP sessions
Exec=pkexec /bin/sh -c 'cp -f /etc/xrdp/startwm.sh.ct105.bak /etc/xrdp/startwm.sh; chmod +x /etc/xrdp/startwm.sh; systemctl restart xrdp xrdp-sesman'
Icon=preferences-desktop
Terminal=false
Categories=Settings;
EOF
chmod +x /root/Desktop/90_DISABLE_CITRIX_ONLY.desktop

systemctl restart xrdp xrdp-sesman
sleep 1

echo STATUS
systemctl is-active xrdp || true
systemctl is-active xrdp-sesman || true

echo FILES
ls -l /usr/local/bin/ct105-citrix-vpn-session.sh /usr/local/bin/ct105-rdp-entrypoint.sh /usr/local/bin/ct105-ica-autostart.sh /etc/xrdp/startwm.sh 2>/dev/null || true

echo XRDP_STARTWM
sed -n '1,80p' /etc/xrdp/startwm.sh

echo VPN_BIN_CHECK
for c in /opt/cisco/anyconnect/bin/vpn /opt/cisco/secureclient/bin/vpn /opt/cisco/anyconnect/bin/vpnui /opt/cisco/secureclient/bin/vpnui; do
  if [ -x "$c" ]; then echo "FOUND:$c"; else echo "MISS:$c"; fi
done

echo CITRIX_BIN_CHECK
for c in /opt/Citrix/ICAClient/selfservice /opt/Citrix/ICAClient/wfica; do
  if [ -x "$c" ]; then echo "FOUND:$c"; else echo "MISS:$c"; fi
done

echo WFCLIENT_RES
grep -E '^(DesiredHRES|DesiredVRES|DesiredColor|UseFullScreen|EnhancedResizingEnabled|ClientClipboard)[[:space:]]*=' /root/.ICAClient/wfclient.ini | sed -n '1,20p' || true

echo XRDP_CLIPBOARD
grep -E '^(allow_channels=|cliprdr=|rdpdr=)' /etc/xrdp/xrdp.ini | sed -n '1,40p' || true

echo SESMAN_CLIPBOARD
grep -Ei '^(EnableClipboard|RestrictInboundClipboard|RestrictOutboundClipboard)=' /etc/xrdp/sesman.ini | sed -n '1,40p' || true

echo SESMAN_SESSIONS
grep -Ei '^(Policy|KillDisconnected|DisconnectedTimeLimit|IdleTimeLimit)=' /etc/xrdp/sesman.ini | sed -n '1,40p' || true

echo MIMEAPPS
sed -n '1,80p' /root/.config/mimeapps.list 2>/dev/null || true

echo ICA_CERTS_CHECK
if [ -d /opt/Citrix/ICAClient/keystore/cacerts ]; then
  ls -1 /opt/Citrix/ICAClient/keystore/cacerts | wc -l | awk '{print "TOTAL_CERT_ENTRIES:"$1}'
  ls -1 /opt/Citrix/ICAClient/keystore/cacerts | sed -n '1,8p'
else
  echo MISS:/opt/Citrix/ICAClient/keystore/cacerts
fi

echo BROWSER_CHECK
for c in firefox chromium google-chrome; do
  if command -v "$c" >/dev/null 2>&1; then echo "FOUND:$c"; else echo "MISS:$c"; fi
done

echo TOOLS_CHECK
for c in wmctrl xdotool autocutsel xclip; do
  if command -v "$c" >/dev/null 2>&1; then echo "FOUND:$c"; else echo "MISS:$c"; fi
done

echo XFWM_CHECK
for c in xfwm4 xfconf-query; do
  if command -v "$c" >/dev/null 2>&1; then echo "FOUND:$c"; else echo "MISS:$c"; fi
done
pgrep -a xfwm4 | sed -n '1,5p' || echo "XFWM4_NOT_RUNNING"
if command -v xfconf-query >/dev/null 2>&1; then
  for p in /general/use_compositing /general/box_move /general/box_resize /general/snap_to_border /general/snap_to_windows /general/snap_width /general/tile_on_move; do
    v=$(xfconf-query -c xfwm4 -p "$p" 2>/dev/null)
    echo "XFWM4${p}=${v}"
  done
fi

echo RDP_CITRIX_VPN_ONLY_END
'''

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(
  hostname=HOST,
  username=USER,
  password=PASSWORD,
  timeout=25,
  banner_timeout=120,
  auth_timeout=60,
  look_for_keys=False,
  allow_agent=False,
)
stdin, stdout, stderr = client.exec_command(REMOTE_SCRIPT, get_pty=True)
print(stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err.strip():
    print('--- STDERR ---')
    print(err)
client.close()
