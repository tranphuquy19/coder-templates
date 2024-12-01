terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}

provider "docker" {}

resource "coder_agent" "main" {
  arch                     = data.coder_provisioner.me.arch
  os                       = data.coder_provisioner.me.os
  startup_script_behavior  = "blocking"
  startup_script          = <<-EOT
    set -e

    # Configure environment
    export HOME=/home/coder
    export USER=coder

    # Install required packages
    sudo apt-get update
    sudo apt-get install -y bc curl wget git

    # Install and configure code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &

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
    syncthing --generate=~/.config/syncthing
    sed -i 's/<address>127.0.0.1:8384<\/address>/<address>0.0.0.0:8384<\/address>/' ~/.config/syncthing/config.xml

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
  EOT

  metadata {
    display_name = "Health Status"
    key          = "0_health_status"
    script       = "/home/coder/health-check.sh"
    interval     = 5
    timeout      = 5
  }

  metadata {
    display_name = "CPU Usage"
    key          = "1_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "2_memory_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Disk Usage"
    key          = "3_disk_usage"
    script       = "coder stat disk"
    interval     = 60
    timeout      = 1
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = "codercom/enterprise-base:ubuntu"
  name  = "coder-${data.coder_workspace.me.id}"
  user  = "1000"

  hostname = "coder-${lower(data.coder_workspace.me.name)}"

  ports {
    internal = 8384
    external = 8384
  }
  ports {
    internal = 22000
    external = 22000
  }
  ports {
    internal = 21027
    external = 21027
    protocol = "udp"
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = false
  }

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.coder_volume.name
    read_only      = false
  }

  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "SHELL=/bin/bash",
    "TERM=xterm"
  ]

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  memory = 4096
  cpu_shares = 1024
  init = true
}

resource "docker_volume" "coder_volume" {
  name = "coder-${data.coder_workspace.me.id}"
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "syncthing" {
  agent_id     = coder_agent.main.id
  slug         = "syncthing"
  display_name = "Syncthing"
  url          = "http://localhost:8384"
  icon         = "/icon/filebrowser.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8384/rest/system/version"
    interval  = 5
    threshold = 6
  }
}