import requests, json, urllib3
urllib3.disable_warnings()

BASE = "https://192.168.0.135:9443/api"


# Auth
r = requests.post(f"{BASE}/auth", json={"Username": "admin", "Password": "mX8zS-A-xVCsOdBe9t7ZdhfCGxquEEFF"}, verify=False, timeout=10)
if "jwt" not in r.json():
    print("AUTH ERROR", r.text)
    exit(1)
token = r.json()["jwt"]
H = {"Authorization": f"Bearer {token}"}
print("AUTH OK")

# Stacks
stacks = requests.get(f"{BASE}/stacks", headers=H, verify=False, timeout=10).json()
print(f"\n=== STACKS ({len(stacks)}) ===")
for s in stacks:
    print(f"  {s['Name']} | ID:{s['Id']} | Status:{s.get('Status','?')} | Type:{s.get('Type','?')}")

# Containers
cs = requests.get(f"{BASE}/endpoints/3/docker/containers/json?all=true", headers=H, verify=False, timeout=10).json()
print(f"\n=== CONTAINERS ({len(cs)}) ===")
for c in cs:
    name = c["Names"][0].lstrip("/")
    ports_list = []
    for p in c.get("Ports", []):
        pub = p.get("PublicPort", "")
        priv = p.get("PrivatePort", "")
        if pub:
            ports_list.append(f"{pub}->{priv}")
        elif priv:
            ports_list.append(str(priv))
    ports = ", ".join(ports_list)
    print(f"  {name} | {c['Image']} | {c['State']} | {c['Status']} | {ports}")

# Docker info
info = requests.get(f"{BASE}/endpoints/3/docker/info", headers=H, verify=False, timeout=10).json()
mem_gb = round(info["MemTotal"] / (1024**3), 1)
print(f"\n=== DOCKER HOST ===")
print(f"  Name: {info['Name']}")
print(f"  OS: {info['OperatingSystem']}")
print(f"  Kernel: {info['KernelVersion']}")
print(f"  CPUs: {info['NCPU']}")
print(f"  RAM: {mem_gb} GB")
print(f"  Docker: {info['ServerVersion']}")
print(f"  Containers: {info['Containers']} (Running:{info['ContainersRunning']}, Stopped:{info['ContainersStopped']})")

# Volumes
vols = requests.get(f"{BASE}/endpoints/3/docker/volumes", headers=H, verify=False, timeout=10).json()
vol_list = vols.get("Volumes", [])
print(f"\n=== VOLUMES ({len(vol_list)}) ===")
for v in vol_list:
    print(f"  {v['Name']} | {v['Driver']}")

# Networks (skip defaults)
nets = requests.get(f"{BASE}/endpoints/3/docker/networks", headers=H, verify=False, timeout=10).json()
print(f"\n=== NETWORKS ({len(nets)}) ===")
for n in nets:
    print(f"  {n['Name']} | {n['Driver']} | {n['Scope']}")

# Images
imgs = requests.get(f"{BASE}/endpoints/3/docker/images/json", headers=H, verify=False, timeout=10).json()
print(f"\n=== IMAGES ({len(imgs)}) ===")
for i in imgs:
    tags = ", ".join(i.get("RepoTags") or ["<none>"])
    sz = round(i["Size"] / (1024**2), 1)
    print(f"  {tags} | {sz}MB")

# Proxmox info (try port 8006)
print("\n=== PROXMOX API ===")
try:
    pr = requests.get("https://192.168.0.135:8006/api2/json/nodes", verify=False, timeout=5)
    if pr.status_code == 401:
        print("  Proxmox API reachable (auth required)")
    else:
        nodes = pr.json().get("data", [])
        for n in nodes:
            print(f"  Node: {n.get('node')} | Status: {n.get('status')} | CPU: {n.get('cpu')} | Mem: {n.get('mem')}")
except Exception as e:
    print(f"  Proxmox API: {e}")

# Check CT105
print("\n=== CT105 (192.168.0.137) ===")
import socket
for port, svc in [(22, "SSH"), (8080, "noVNC/code-server"), (3000, "Wiki.js")]:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(3)
    try:
        result = s.connect_ex(("192.168.0.137", port))
        status = "OPEN" if result == 0 else "CLOSED"
    except:
        status = "TIMEOUT"
    finally:
        s.close()
    print(f"  Port {port} ({svc}): {status}")
