import paramiko

HOST = "192.168.0.135"
USER = "root"
PASSWORD = "mX8zS-A-xVCsOdBe9t7ZdhfCGxquEEFF"

COMMANDS = [
    "systemctl is-active docker || service docker status || echo 'docker not found'",
    "docker info || echo 'docker info failed'",
    "docker ps -a || echo 'docker ps failed'"
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
