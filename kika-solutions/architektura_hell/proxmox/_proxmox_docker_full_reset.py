import paramiko

HOST = "192.168.0.135"
USER = "root"
PASSWORD = "mX8zS-A-xVCsOdBe9t7ZdhfCGxquEEFF"

COMMANDS = [
    "systemctl stop docker || service docker stop || true",
    "apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras || true",
    "apt-get autoremove -y || true",
    "rm -rf /var/lib/docker /var/lib/containerd /etc/docker /etc/containerd /var/run/docker.sock",
    "apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras",
    "systemctl enable --now docker || service docker start"
]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(
    hostname=HOST,
    username=USER,
    password=PASSWORD,
    timeout=60,
    banner_timeout=120,
    auth_timeout=60,
    look_for_keys=False,
    allow_agent=False,
)

for cmd in COMMANDS:
    print(f"\n=== {cmd} ===")
    stdin, stdout, stderr = client.exec_command(cmd, get_pty=True)
    print(stdout.read().decode('utf-8', errors='replace'))
    err = stderr.read().decode('utf-8', errors='replace')
    if err.strip():
        print('--- STDERR ---')
        print(err)

client.close()
print("\nDocker byl kompletně odinstalován, všechna data smazána a Docker znovu nainstalován.")
