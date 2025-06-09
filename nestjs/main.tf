# Terraform configuration
terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# Provider configuration
provider "docker" {}

# Data sources
data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}

# Random ports
resource "random_integer" "code_server_port" {
  min = 32768
  max = 60999
}

resource "random_integer" "syncthing_ui_port" {
  min = 32768
  max = 60999
}

resource "random_integer" "syncthing_listen_port" {
  min = 32768
  max = 60999
}

resource "random_integer" "syncthing_discovery_port" {
  min = 32768
  max = 60999
}

# Local variables
locals {
  home_dir      = "/home/coder"
  username      = "coder"
  image         = "codercom/enterprise-base:ubuntu"
  memory        = 25795
  cpu_shares    = 4096
  ports = concat(
    [
      { internal = 13337, external = random_integer.code_server_port.result, protocol = "tcp" }
    ],
    [
      { internal = 8384,  external = random_integer.syncthing_ui_port.result,       protocol = "tcp" },
      { internal = 22000, external = random_integer.syncthing_listen_port.result,   protocol = "tcp" },
      { internal = 21027, external = random_integer.syncthing_discovery_port.result, protocol = "udp" }
    ]
  )
}

# Agent configuration
resource "coder_agent" "main" {
  arch                    = data.coder_provisioner.me.arch
  os                      = data.coder_provisioner.me.os
  startup_script_behavior = "blocking"
  startup_script          = file("${path.module}/startup.sh")

  env = {
    CODE_SERVER_PORT = random_integer.code_server_port.result
    SYNCTHING_UI_PORT = random_integer.syncthing_ui_port.result
    SYNCTHING_LISTEN_PORT = random_integer.syncthing_listen_port.result
    SYNCTHING_DISCOVERY_PORT = random_integer.syncthing_discovery_port.result
  }

  # System monitoring metadata
  metadata {
    display_name = "Health Status"
    key          = "0_health_status"
    script       = "${local.home_dir}/health-check.sh"
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

# Docker resources
resource "docker_volume" "coder_volume" {
  name = "coder-${data.coder_workspace.me.id}"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count

  image    = local.image
  name     = "coder-${data.coder_workspace.me.id}"
  user     = "1000"
  hostname = "coder-${lower(data.coder_workspace.me.name)}"

  dynamic "ports" {
    for_each = local.ports
    content {
      internal = ports.value.internal
      external = ports.value.external
      protocol = ports.value.protocol
    }
  }

  volumes {
    container_path = "/var/run/docker.sock"
    host_path      = "/var/run/docker.sock"
    read_only      = false
  }

  volumes {
    container_path = local.home_dir
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

  memory      = local.memory
  memory_swap = local.memory * 2
  cpu_shares  = local.cpu_shares
  init        = true
}

# Applications
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:${random_integer.code_server_port.result}/?folder=${local.home_dir}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:${random_integer.code_server_port.result}/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "syncthing" {
  agent_id     = coder_agent.main.id
  slug         = "syncthing"
  display_name = "Syncthing"
  url          = "http://localhost:${random_integer.syncthing_ui_port.result}"
  icon         = "/icon/filebrowser.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:${random_integer.syncthing_ui_port.result}/rest/system/version"
    interval  = 5
    threshold = 6
  }
}
