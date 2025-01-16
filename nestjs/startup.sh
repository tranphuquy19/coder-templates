set -e

# Configure environment
export HOME=/home/coder
export USER=coder

# Install required packages
sudo apt-get update
sudo apt-get install -y bc curl wget git apt-transport-https ca-certificates gnupg lsb-release software-properties-common bash-completion dnsutils telnet iputils-ping

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update
sudo apt-get install -y terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256) kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl kubectl.sha256

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
echo "Verifying installations..."
terraform version
kubectl version --client
helm version --client

# Configure kubectl completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

# Configure Helm completion
echo 'source <(helm completion bash)' >>~/.bashrc

# Install and configure code-server
curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
/tmp/code-server/bin/code-server --auth none --port ${CODE_SERVER_PORT} >/tmp/code-server.log 2>&1 &

# Install and configure atuin
bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)
source $HOME/.atuin/bin/env

mkdir -p ~/.config/atuin
touch ~/.config/atuin/config.toml
echo 'enter_accept = false' > ~/.config/atuin/config.toml
echo 'filter_mode_shell_up_key_binding = "directory"' >> ~/.config/atuin/config.toml

$HOME/.atuin/bin/atuin daemon &
$HOME/.atuin/bin/atuin init bash
echo 'eval "$(atuin init bash)"' >> ~/.bashrc

# Install and configure pnpm
curl -fsSL https://get.pnpm.io/install.sh | SHELL=/bin/bash sh -
export PNPM_HOME="/home/coder/.local/share/pnpm"

case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

echo 'export PNPM_HOME="/home/coder/.local/share/pnpm"' >> ~/.bashrc
echo 'case ":$PATH:" in' >> ~/.bashrc
echo '  *":$PNPM_HOME:"*) ;;' >> ~/.bashrc
echo '  *) export PATH="$PNPM_HOME:$PATH" ;;' >> ~/.bashrc
echo 'esac' >> ~/.bashrc

pnpm env use --global 20
pnpm add -g @nestjs/cli typescript ts-node

# Install and configure Syncthing
sudo curl -o /usr/share/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg
echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | sudo tee /etc/apt/sources.list.d/syncthing.list
sudo apt update
sudo apt install syncthing -y

# Create Syncthing config directory
mkdir -p ~/.config/syncthing
# syncthing --generate=~/.config/syncthing
# Configure Syncthing
cat > ~/.config/syncthing/config.xml <<EOF
<configuration version="30">
    <gui enabled="true">
        <address>0.0.0.0:${SYNCTHING_UI_PORT}</address>
    </gui>
    <options>
        <listenAddress>default</listenAddress>
        <globalAnnounceEnabled>true</globalAnnounceEnabled>
        <localAnnounceEnabled>true</localAnnounceEnabled>
        <relaysEnabled>true</relaysEnabled>
    </options>
</configuration>
EOF

# Create Syncthing management script
cat > ~/syncthing.sh << 'EOL'
#!/bin/bash

export HOME="/home/coder"
export USER="coder"

start() {
    if [ -f "$HOME/.config/syncthing/syncthing.pid" ]; then
        if ps -p $(cat $HOME/.config/syncthing/syncthing.pid) > /dev/null; then
            echo "Syncthing is already running"
            return
        else
            rm $HOME/.config/syncthing/syncthing.pid
        fi
    fi
  
    nohup syncthing \
        --no-browser \
        --home="$HOME/.config/syncthing" \
        > "$HOME/.config/syncthing/syncthing.log" 2>&1 &
  
    echo $! > "$HOME/.config/syncthing/syncthing.pid"
    echo "Syncthing started"
}

stop() {
    if [ -f "$HOME/.config/syncthing/syncthing.pid" ]; then
        kill $(cat "$HOME/.config/syncthing/syncthing.pid")
        rm "$HOME/.config/syncthing/syncthing.pid"
        echo "Syncthing stopped"
    else
        echo "Syncthing is not running"
    fi
}

status() {
    if [ -f "$HOME/.config/syncthing/syncthing.pid" ]; then
        if ps -p $(cat "$HOME/.config/syncthing/syncthing.pid") > /dev/null; then
            echo "1"
        else
            rm "$HOME/.config/syncthing/syncthing.pid"
            echo "0"
        fi
    else
        echo "0"
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 2
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOL

chmod +x ~/syncthing.sh
~/syncthing.sh start

# Create health check script
cat > ~/health-check.sh <<'EOF'
#!/bin/bash

export HOME="/home/coder"
export USER="coder"

check_process() {
    if pgrep -u coder "$1" > /dev/null; then
        echo "1"
    else
        echo "0"
    fi
}

check_disk_space() {
    local free_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    if (( $(echo "$free_space > 1" | bc -l) )); then
        echo "1"
    else
        echo "0"
    fi
}

check_memory() {
    local free_mem=$(free -g | awk 'NR==2 {print $4}')
    if (( free_mem > 1 )); then
        echo "1"
    else
        echo "0"
    fi
}

check_syncthing() {
    ~/syncthing.sh status
}

main_check() {
    local code_server_status=$(check_process "code-server")
    local atuin_status=$(check_process "atuin")
    local syncthing_status=$(check_syncthing)
    local disk_status=$(check_disk_space)
    local memory_status=$(check_memory)
    
    if [[ "$code_server_status" == "1" && "$atuin_status" == "1" && \
          "$syncthing_status" == "1" && "$disk_status" == "1" && \
          "$memory_status" == "1" ]]; then
        echo "1"
    else
        echo "0"
    fi
}

main_check
EOF

chmod +x ~/health-check.sh
