import paramiko

HOST = "192.168.0.135"
USER = "root"
PASSWORD = "mX8zS-A-xVCsOdBe9t7ZdhfCGxquEEFF"

COMMANDS = [
    "docker stop portainer || true",
    "docker rm portainer || true",
    "docker volume rm portainer_data || true",
    "docker run -d -p 9443:9443 -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest"
]

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(
    hostname=HOST,
    username=USER,
    password=PASSWORD,
    timeout=30,
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
print("\nPortainer byl restartován s přístupem k Docker socketu. Zkus znovu přidat prostředí v Portaineru.")
