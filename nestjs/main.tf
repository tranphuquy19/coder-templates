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
data "coder_workspace_owner" "me" {}

locals {
  username = data.coder_workspace_owner.me.name
}

provider "docker" {}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = data.coder_provisioner.me.os

  startup_script_behavior = "blocking"
  startup_script = <<-EOT
    set -e

    # Ensure shell environment is properly set
    export SHELL=/bin/bash
    export TERM=xterm

    # Install required packages
    sudo apt-get update
    sudo apt-get install -y bc
  
    # Install the latest code-server.
    # Append "--version x.x.x" to install a specific version of code-server.
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server

    # Start code-server in the background.
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  
    # Install atuin
    bash <(curl https://raw.githubusercontent.com/atuinsh/atuin/main/install.sh)
  
    # Source atuin environment
    source $HOME/.atuin/bin/env
  
    # Create atuin config directory and file
    mkdir -p ~/.config/atuin
    touch ~/.config/atuin/config.toml
  
    # Configure atuin
    echo 'enter_accept = false' > ~/.config/atuin/config.toml
    echo 'filter_mode_shell_up_key_binding = "directory"' >> ~/.config/atuin/config.toml
  
    # Start atuin daemon
    $HOME/.atuin/bin/atuin daemon &
  
    # Initialize atuin history
    $HOME/.atuin/bin/atuin init bash
  
    # Install and configure pnpm
    curl -fsSL https://get.pnpm.io/install.sh | SHELL=/bin/bash sh -
    export PNPM_HOME="/home/coder/.local/share/pnpm"
    source /home/coder/.bashrc

    # Add pnpm to PATH
    case ":$PATH:" in
      *":$PNPM_HOME:"*) ;;
      *) export PATH="$PNPM_HOME:$PATH" ;;
    esac

    # Install Node.js and global packages
    pnpm env use --global 20
    pnpm add -g @nestjs/cli typescript ts-node

    # Install code-server extensions
  
    # Add atuin to shell rc
    echo 'eval "$(atuin init bash)"' >> ~/.bashrc

    # Create health check script
    cat > /home/coder/health-check.sh <<'EOF'
    #!/bin/bash
  
    # Check if essential processes are running
    check_process() {
        if pgrep "$1" > /dev/null; then
            echo "1"
        else
            echo "0"
        fi
    }
  
    # Check available disk space
    check_disk_space() {
        local free_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
        if (( $(echo "$free_space > 1" | bc -l) )); then
            echo "1"
        else
            echo "0"
        fi
    }
  
    # Check memory usage
    check_memory() {
        local free_mem=$(free -g | awk 'NR==2 {print $4}')
        if (( free_mem > 1 )); then
            echo "1"
        else
            echo "0"
        fi
    }
  
    # Main health check
    main_check() {
        local code_server_status=$(check_process "code-server")
        local atuin_status=$(check_process "atuin")
        local disk_status=$(check_disk_space)
        local memory_status=$(check_memory)
      
        if [[ "$code_server_status" == "1" && "$atuin_status" == "1" && \
              "$disk_status" == "1" && "$memory_status" == "1" ]]; then
            echo "1"
        else
            echo "0"
        fi
    }
  
    main_check
    EOF
  
    chmod +x /home/coder/health-check.sh
  EOT

  # Health check metadata
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

  # Refer to Docker host when Coder connects via SSH
  hostname = "coder-${lower(data.coder_workspace.me.name)}"

  # Add Docker socket mount
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

  # Basic container configuration
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

  # Resources configuration
  memory = 4096
  cpu_shares = 1024

  # Use init process
  init = true

  # Basic volume configuration
  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.coder_volume.name
    read_only     = false
  }
}

resource "docker_volume" "coder_volume" {
  name = "coder-${data.coder_workspace.me.id}"
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}
