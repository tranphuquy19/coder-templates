# 🚀 Provision Scripts for Coder.io

<div align="center">

![Coder](https://img.shields.io/badge/Coder.io-1D1D1D?style=for-the-badge&logo=coder&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)

A comprehensive development environment setup using Infrastructure as Code.

[![VS Code](https://img.shields.io/badge/VS_Code-007ACC?style=flat-square&logo=visualstudiocode&logoColor=white)](#)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)](#)
[![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat-square&logo=helm&logoColor=white)](#)
[![Syncthing](https://img.shields.io/badge/Syncthing-0891B2?style=flat-square&logo=syncthing&logoColor=white)](#)
[![PNPM](https://img.shields.io/badge/PNPM-F69220?style=flat-square&logo=pnpm&logoColor=white)](#)

</div>

---

## 📋 Overview

### ✨ Key Features:
- 🏗️ **Terraform Configuration**
  - Docker containers & volumes management
  - Dynamic port allocation
  - Automated health monitoring

- 🔄 **Startup Automation**
  - Development tools installation
  - Environment configuration
  - Service management

- 🎯 **Core Applications**
  - 💻 VS Code Server (code-server)
  - 🔄 Syncthing
  - 📦 Package managers & dev tools

---

## 🗂️ File Structure

```
.
├── 📄 main.tf          # Infrastructure configuration
├── 📄 startup.sh       # Environment setup script
└── 📄 health-check.sh  # Monitoring script
```

---

## 🔧 Prerequisites

<div align="center">

| Tool | Version | Description |
|:----:|:-------:|:------------|
| ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white) | Latest | Container runtime |
| ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white) | ≥ 1.0 | IaC tool |

</div>

---

## ⚙️ Terraform Configuration

### 🔌 Providers:
- ![Coder](https://img.shields.io/badge/Coder-1D1D1D?style=flat-square&logo=coder&logoColor=white) **Coder**
- ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white) **Docker**
- 🎲 **Random**

### 🏗️ Key Resources:
```hcl
coder_agent
docker_container
docker_volume
coder_app
```

---

## 🛠️ Installed Tools

<div align="center">

| Tool | Purpose |
|:----:|:--------|
| ![VS Code](https://img.shields.io/badge/VS_Code-007ACC?style=flat-square&logo=visualstudiocode&logoColor=white) | Remote IDE |
| ![Kubernetes](https://img.shields.io/badge/kubectl-326CE5?style=flat-square&logo=kubernetes&logoColor=white) | K8s CLI |
| ![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat-square&logo=helm&logoColor=white) | K8s Package Manager |
| ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white) | IaC Tool |
| ![PNPM](https://img.shields.io/badge/PNPM-F69220?style=flat-square&logo=pnpm&logoColor=white) | Package Manager |
| ![Syncthing](https://img.shields.io/badge/Syncthing-0891B2?style=flat-square&logo=syncthing&logoColor=white) | File Sync |

</div>

---

## 📊 Monitoring

### 🔍 Health Checks:
- 🟢 Service Status
- 📊 CPU Usage
- 💾 Memory Usage
- 💽 Disk Space
- 🔄 Syncthing Status

---

## 🚀 Usage

1. **Initialize:**
```bash
terraform init
```

2. **Deploy:**
```bash
terraform apply
```

3. **Access Applications:**
- 💻 **VS Code**: `http://localhost:<code_server_port>`
- 🔄 **Syncthing**: `http://localhost:<syncthing_ui_port>`

---

## 🔧 Troubleshooting

### 🚨 Common Issues:

| Issue | Solution |
|:------|:---------|
| 🐳 Docker not running | Start Docker daemon |
| 🔌 Port conflicts | Adjust port ranges in `main.tf` |
| ❌ Failed health checks | Check service logs |

---

## 📄 License

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🤝 Contribution

Feel free to contribute! Open issues or submit PRs to improve the scripts.

<div align="center">

[![GitHub Issues](https://img.shields.io/github/issues/username/repo?style=flat-square)](https://github.com/username/repo/issues)
[![GitHub PRs](https://img.shields.io/github/issues-pr/username/repo?style=flat-square)](https://github.com/username/repo/pulls)

</div>

---

<div align="center">

Made with ❤️ for the developer community

</div>
