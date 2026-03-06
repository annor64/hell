import paramiko
import time

HOST = "192.168.0.135"
USER = "root"
PASSWORD = "mX8zS-A-xVCsOdBe9t7ZdhfCGxquEEFF"

COMMANDS = [
    # Portainer
    "docker volume create portainer_data",
    "docker run -d -p 9443:9443 -p 9000:9000 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest",
    # Home Assistant (pouze volume, stack připravíme v Portaineru)
    "docker volume create homeassistant_config"
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
    while not stdout.channel.exit_status_ready():
        time.sleep(0.5)
        if stdout.channel.recv_ready():
            print(stdout.channel.recv(4096).decode('utf-8', errors='replace'), end="")
    print(stdout.read().decode('utf-8', errors='replace'))
    err = stderr.read().decode('utf-8', errors='replace')
    if err.strip():
        print('--- STDERR ---')
        print(err)

client.close()
print("\nPortainer je nasazen na https://192.168.0.135:9443 a volume pro Home Assistant je připraveno. Pokračuj v Portaineru přidáním prostředí a stacku.")
