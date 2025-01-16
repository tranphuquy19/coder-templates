# Provision Scripts for Coder.io

This repository contains Terraform and shell scripts to provision and configure a development environment using Coder.io, Docker, and other tools. The setup includes automated installation, configuration, and health monitoring of essential services and applications.

---

## Overview

### Key Features:
- **Terraform Configuration**:
  - Manages Docker containers, volumes, and resources.
  - Automates the provisioning of ports using `random_integer`.
  - Sets up Coder agents, applications, and health monitoring scripts.

- **Startup Script**:
  - Installs essential tools (`terraform`, `kubectl`, `helm`, etc.).
  - Configures `code-server`, `Syncthing`, and other utilities.
  - Implements health checks and environment configurations.

- **Applications**:
  - **code-server**: Remote development environment.
  - **Syncthing**: File synchronization service.

---

## File Structure

- **`main.tf`**: Terraform configuration file that defines infrastructure resources and applications.
- **`startup.sh`**: Shell script to initialize and configure the environment.
- **`health-check.sh`**: Script to monitor the health of key services and system resources.

---

## Prerequisites

Ensure the following tools are installed before running the scripts:
- **Terraform** (>= 1.0)
- **Docker** (latest stable version)

---

## Terraform Configuration

### Providers:
- **Coder**: Manages Coder.io resources.
- **Docker**: Manages Docker containers and volumes.
- **Random**: Generates random ports to avoid conflicts.

### Resources:
- **`coder_agent`**: Configures the Coder agent with environment variables and metadata for monitoring.
- **`docker_container`**: Creates a Docker container for the development workspace.
- **`docker_volume`**: Defines persistent storage for the workspace.
- **`coder_app`**: Sets up applications like `code-server` and `Syncthing`.

### Local Variables:
- **`home_dir`**: Default home directory for the user (`/home/coder`).
- **`ports`**: Dynamically assigned ports for applications and services.

---

## Startup Script (`startup.sh`)

This script automates the installation and configuration of tools and services:

### Tools Installed:
1. **Terraform**: Infrastructure as Code (IaC) tool.
2. **kubectl**: Kubernetes CLI.
3. **Helm**: Kubernetes package manager.
4. **code-server**: Remote development server.
5. **Syncthing**: File synchronization tool.
6. **pnpm**: JavaScript package manager.
7. **Atuin**: Enhanced shell history management.

### Key Configurations:
- **Environment Variables**: Sets up paths and ports for installed services.
- **Service Management**: Includes scripts to start, stop, and monitor Syncthing.
- **Health Checks**: Ensures all services are running and system resources are sufficient.

---

## Health Check Script (`health-check.sh`)

Monitors system health and service statuses:
- **Processes**: Verifies if `code-server`, `Syncthing`, and `Atuin` are running.
- **Disk Space**: Checks for sufficient free space (>1GB).
- **Memory**: Ensures adequate free memory (>1GB).
- **Syncthing Status**: Uses the Syncthing management script to verify its state.

---

## Applications

### 1. **code-server**
- **Description**: A remote development environment accessible via a browser.
- **URL**: `http://localhost:<random_port>/`
- **Health Check**: Monitors `/healthz` endpoint.

### 2. **Syncthing**
- **Description**: A file synchronization service.
- **URL**: `http://localhost:<random_port>/`
- **Health Check**: Monitors `/rest/system/version` endpoint.

---

## Usage

### Step 1: Initialize Terraform
```bash
terraform init
```

### Step 2: Apply Configuration
```bash
terraform apply
```

### Step 3: Access Applications
- **code-server**: Visit `http://localhost:<code_server_port>` in your browser.
- **Syncthing**: Visit `http://localhost:<syncthing_ui_port>` in your browser.

---

## Customization

### Ports:
- Update the `random_integer` resources in `main.tf` to customize the port ranges.

### Resources:
- Modify `local` variables to adjust memory, CPU shares, or Docker image.

---

## Monitoring

The system includes metadata and health-check scripts for monitoring:
- **Health Status**: Verifies all services and resources are operational.
- **CPU, Memory, Disk Usage**: Monitors system performance using `coder stat`.

---

## Troubleshooting

### Common Issues:
1. **Docker Not Running**: Ensure Docker is installed and running on the host machine.
2. **Port Conflicts**: Update the `random_integer` port ranges to avoid conflicts.
3. **Health Checks Failing**: Check logs in `/tmp/code-server.log` or `~/.config/syncthing/syncthing.log`.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Contribution

Feel free to open issues or submit pull requests to improve the scripts or documentation.
