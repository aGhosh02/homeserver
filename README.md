# 🏠 Proxmox Homeserver Automation

[![Ansible Lint](https://github.com/actions/workflow_run?workflow=ansible-lint)](https://github.com/actions/workflows/ansible-lint.yml)
[![Made with Ansible](https://img.shields.io/badge/Made%20with-Ansible-red.svg)](https://www.ansible.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-1.0.0-blue.svg)](CHANGELOG.md)

> **A comprehensive, production-ready Ansible automation suite for Proxmox VE homeserver deployment and management.**

This repository provides a complete infrastructure-as-code solution for automated Proxmox VE homeserver setup, featuring advanced configuration management, security hardening, GPU passthrough automation, and VM deployment capabilities.

## 🌟 Key Features

### 🔧 **Core Automation**
- **Automated Proxmox VE Configuration**: Complete base system setup with security hardening
- **Intelligent Package Management**: Repository configuration and essential package installation
- **System Optimization**: Kernel tuning and performance optimizations for virtualization workloads

### 🌐 **Advanced Networking**
- **Dedicated VM Network**: Isolated bridge network (vmbr1) with NAT configuration
- **Firewall Integration**: Automated iptables rules for secure VM internet access
- **Network Segmentation**: Proper isolation between management and VM networks

### 🎮 **GPU Passthrough Automation**
- **IOMMU Configuration**: Automated kernel parameter setup for Intel/AMD systems
- **VFIO Driver Management**: Automated GPU binding and driver blacklisting
- **Validation Tools**: Comprehensive GPU passthrough verification scripts

### 🏠 **VM Deployment**
- **Home Assistant OS**: Automated HAOS VM deployment with optimized configuration
- **OpenMediaVault**: NAS VM deployment with disk passthrough and SATA controller
- **Docker LXC**: Privileged container platform for hosting multiple Docker services
- **Resource Management**: Intelligent resource allocation and optimization
- **Template Support**: Extensible VM deployment templates

### 🔒 **Security & Management**
- **Ansible Vault Integration**: Secure credential and sensitive data management
- **Comprehensive Logging**: Detailed audit trails and deployment logging
- **Health Monitoring**: Built-in system health checks and diagnostics
- **Backup Automation**: Configuration backup and disaster recovery tools

## 📋 System Requirements

### Control Machine (Ansible Host)
| Component | Requirement | Recommended |
|-----------|-------------|-------------|
| **OS** | Linux, macOS, WSL2 | Ubuntu 22.04+ |
| **Python** | 3.8+ | 3.10+ |
| **Ansible** | 2.12+ | Latest stable |
| **Memory** | 2GB RAM | 4GB RAM |
| **Storage** | 1GB free | 5GB free |

### Target Machine (Proxmox Host)
| Component | Requirement | Recommended |
|-----------|-------------|-------------|
| **OS** | Proxmox VE 7.x/8.x | Proxmox VE 8.x |
| **CPU** | VT-x/VT-d or AMD-V/AMD-Vi | Modern multi-core |
| **Memory** | 8GB RAM | 32GB+ RAM |
| **Storage** | 100GB | 500GB+ SSD |
| **Network** | Static IP, SSH access | Gigabit Ethernet |

## 🚀 Quick Start

### 1. **Prerequisites Check**
```bash
# Verify dependencies
make check-deps
```

### 2. **Project Setup**
```bash
# Clone repository
git clone https://github.com/your-repo/homeserver.git
cd homeserver

# Install dependencies
make setup
```

### 3. **Configuration**
```bash
# Configure target hosts
vim ansible/inventories/production/hosts.yml

# Set up secrets (optional but recommended)
make edit-vault
```

### 4. **Deployment**
```bash
# Test connectivity
make validate

# Deploy (dry-run first)
make dry-run
make run
```

## 🛠️ Advanced Usage

### **Selective Deployment**
```bash
make run-base      # Base system configuration only
make run-network   # Network setup only  
make run-gpu       # GPU passthrough only
make deploy-haos   # Home Assistant OS deployment
make deploy-omv    # OpenMediaVault NAS deployment
```

### **Maintenance Operations**
```bash
make maintenance   # System updates and maintenance
make validate      # System validation and health checks
make backup        # Create configuration backup
make clean         # Clean temporary files
```

### **Development & Testing**
```bash
make test          # Run comprehensive tests
make lint          # Code quality checks
make syntax-check  # Playbook syntax validation
make security-check # Security auditing
```

## 📂 Project Architecture

```
homeserver/
├── 📁 ansible/                 # Main Ansible directory
│   ├── 📄 ansible.cfg          # Ansible configuration
│   ├── 📄 requirements.yml     # Dependencies specification
│   ├── 📁 inventories/         # Host and group configurations
│   │   └── 📁 production/      # Production environment
│   ├── 📁 playbooks/           # Main orchestration playbooks
│   │   ├── 📄 site.yml         # Primary deployment playbook
│   │   ├── 📄 maintenance.yml  # System maintenance tasks
│   │   ├── 📄 validate.yml     # Validation and testing
│   │   ├── 📄 deploy-haos.yml  # Home Assistant OS deployment
│   │   └── 📄 deploy-omv.yml   # OpenMediaVault NAS deployment
│   └── 📁 roles/               # Modular configuration roles
│       ├── 📁 proxmox_base/    # Base system configuration
│       ├── 📁 vm_networking/   # Network bridge setup
│       ├── 📁 gpu_passthrough/ # GPU passthrough automation
│       ├── 📁 haos_vm/         # Home Assistant OS deployment
│       ├── 📁 omv_vm/          # OpenMediaVault NAS deployment
│       └── 📁 common/          # Shared validation tasks
├── 📁 docs/                    # Comprehensive documentation
├── 📁 scripts/                 # Utility and management scripts
├── 📄 Makefile                 # Task automation and shortcuts
└── 📄 README.md               # This file
```

## 🧩 Role Overview

### **proxmox_base** - Foundation Configuration
- System package management and repository setup
- Security hardening and system optimization
- NTP synchronization and logging configuration
- Performance tuning for virtualization workloads

### **vm_networking** - Network Infrastructure  
- VM bridge interface creation and configuration
- NAT setup for VM internet connectivity
- Firewall rules and network security policies
- Network isolation and segmentation

### **gpu_passthrough** - Hardware Passthrough
- IOMMU enablement and kernel configuration
- GPU driver management and VFIO binding
- Hardware validation and compatibility checks
- Automated troubleshooting and diagnostics

### **haos_vm** - VM Deployment
- Home Assistant OS VM creation and configuration
- Resource allocation and storage management
- Network attachment and boot configuration
- VM lifecycle management

### **omv_vm** - NAS VM Deployment
- OpenMediaVault NAS VM creation and configuration
- Disk passthrough via SATA controller for direct storage access
- Memory balloon disabled for stable NAS performance
- ISO download and VM installation automation

### **docker_lxc** - Container Platform Deployment
- Privileged LXC container with Docker and Docker Compose
- 4 CPU cores, 16GB RAM with dynamic ballooning
- 100GB+ thin-provisioned storage with bind mounts
- Host directory mounting for data persistence
- Pre-configured sample services (Portainer, Nginx)
- Comprehensive container management tools

## 🔐 Security Features

### **Credential Management**
- **Ansible Vault**: Encrypted storage for sensitive data
- **SSH Key Authentication**: Secure, key-based access
- **Credential Rotation**: Support for credential updates

### **System Hardening**
- **Firewall Configuration**: Automated iptables management
- **Service Minimization**: Disable unnecessary services
- **Access Control**: Proper user and permission management
- **Audit Logging**: Comprehensive activity tracking

### **Network Security**
- **Network Segmentation**: Isolated VM networks
- **Traffic Control**: Granular firewall rules
- **NAT Configuration**: Secure internet access for VMs

## 📊 Monitoring & Maintenance

### **Health Monitoring**
```bash
# System health check
./scripts/health-check.sh

# GPU passthrough diagnostics  
./scripts/gpu-passthrough-manager.sh check

# Docker LXC container management
./scripts/docker-lxc.sh deploy --hostname docker-services
./scripts/docker-lxc.sh status --container-id 200

# Comprehensive validation
make validate
```

### **Log Management**
- **Centralized Logging**: Structured log collection
- **Log Rotation**: Automated log management
- **Audit Trails**: Complete change tracking
- **Error Reporting**: Proactive issue detection

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[Installation Guide](docs/INSTALLATION.md)** | Step-by-step setup instructions |
| **[Architecture Overview](docs/ARCHITECTURE.md)** | System design and components |
| **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** | Common issues and solutions |
| **[API Reference](docs/API.md)** | Variable and configuration reference |
| **[Best Practices](docs/BEST_PRACTICES.md)** | Recommended configurations |

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### **Development Workflow**
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes with proper testing
4. Commit with conventional commit messages
5. Push to your branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### **Code Quality**
- Follow Ansible best practices
- Include comprehensive documentation
- Add appropriate tests
- Ensure security compliance

## 📈 Roadmap

### **Version 1.1** (Planned)
- [ ] Container orchestration support (Docker/Podman)
- [ ] Advanced monitoring with Prometheus/Grafana
- [ ] Automated backup solutions
- [ ] High availability clustering

### **Version 1.2** (Future)
- [ ] Web-based management interface
- [ ] API endpoint integration
- [ ] Multi-site deployment support
- [ ] Advanced security features

## 🆘 Support

### **Getting Help**
- **📖 Documentation**: Check our comprehensive docs
- **🐛 Issues**: Report bugs via GitHub Issues
- **💬 Discussions**: Join our community discussions
- **📧 Contact**: Reach out for enterprise support

### **Community Resources**
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Community Forum](https://forum.proxmox.com/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Proxmox Team**: For the excellent virtualization platform
- **Ansible Community**: For the powerful automation framework
- **Contributors**: Everyone who has contributed to this project

---

<div align="center">

**⭐ Star this repository if you find it useful!**

[📖 Documentation](docs/) • [🐛 Report Bug](../../issues) • [💡 Request Feature](../../issues) • [🤝 Contribute](CONTRIBUTING.md)

</div>

## 🌟 Features

-   **Automated Proxmox VE Configuration**: Sets up the base system, including package installation, repository management, and kernel tuning.
-   **VM Networking**: Creates a dedicated network bridge for virtual machines with NAT and firewall rules.
-   **GPU Passthrough**: Automates the complex process of configuring IOMMU and VFIO for PCI passthrough.
-   **Makefile Integration**: Simplifies common tasks like running playbooks, managing dependencies, and handling secrets.
-   **Validation and Maintenance**: Includes playbooks for system validation and routine maintenance.
-   **Secrets Management**: Securely manage sensitive data using Ansible Vault.

## 📋 Requirements

-   **Ansible** `2.12+` on your control machine.
-   **Proxmox VE** `7.x` or `8.x` installed on the target server(s).
-   **Git** for cloning the repository.
-   SSH access to the Proxmox host(s) with key-based authentication.

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone <your-repository-url>
cd homeserver
```

### 2. Configure the Inventory

Update the inventory file `ansible/inventories/production/hosts.yml` with your Proxmox server's IP address or hostname.

```yaml
# ansible/inventories/production/hosts.yml
---
all:
  hosts:
    proxmox-node1:
      ansible_host: 192.168.1.10
      # Add other host-specific variables here
```

### 3. Customize Variables

Review and adjust the variables in the following files to match your environment and preferences:

-   **Main Configuration**: `ansible/inventories/production/group_vars/proxmox.yml`
-   **Sensitive Data (Vault)**: `ansible/inventories/production/group_vars/all/vault.yml`
-   **Role Defaults**:
    -   `ansible/roles/proxmox_base/defaults/main.yml`
    -   `ansible/roles/vm_networking/defaults/main.yml`
    -   `ansible/roles/gpu_passthrough/defaults/main.yml`

### 4. Install Dependencies

Install the required Ansible collections using the provided `Makefile`:

```bash
make setup
```

This will install the collections defined in `ansible/requirements.yml`.

## 🛠️ Usage

This project uses a `Makefile` to provide convenient shortcuts for common commands.

-   **Show Help**: Display all available commands.
    ```bash
    make help
    ```
-   **Run Full Deployment**: Apply the entire configuration.
    ```bash
    make run
    ```
-   **Run Specific Parts**: Use tags to run specific roles.
    ```bash
    make run-base      # Configure base system
    make run-network   # Configure VM networking
    make run-gpu       # Configure GPU passthrough
    ```
-   **Dry Run**: Simulate changes without applying them.
    ```bash
    make dry-run
    ```
-   **Validate Configuration**: Run validation tasks to check the system state.
    ```bash
    make validate
    ```
-   **Run Maintenance**: Execute maintenance playbooks (e.g., system updates).
    ```bash
    make maintenance
    ```
-   **Lint Ansible Code**: Check playbooks and roles for best practices.
    ```bash
    make lint
    ```

## 📂 Project Structure

```
.
├── Makefile
├── ansible
│   ├── ansible.cfg
│   ├── inventories
│   ├── playbooks
│   └── roles
├── docs
└── scripts
```

-   `Makefile`: Contains shortcuts for common tasks.
-   `ansible/`: The main directory for all Ansible content.
    -   `ansible.cfg`: Ansible configuration file.
    -   `inventories/`: Defines your infrastructure hosts and variables.
    -   `playbooks/`: Contains the main playbooks (`site.yml`, `maintenance.yml`, `validate.yml`).
    -   `roles/`: Reusable Ansible roles for different components.
-   `docs/`: For additional documentation.
-   `scripts/`: Helper scripts.

## 🔐 Vault Management

Sensitive data like passwords and API keys should be stored in the encrypted vault file at `ansible/inventories/production/group_vars/all/vault.yml`.

-   **Edit Vault**: To edit the encrypted file (requires vault password).
    ```bash
    make edit-vault
    ```
-   **Encrypt Vault**: To encrypt the vault file after editing it in plain text.
    ```bash
    make encrypt-vault
    ```
-   **Decrypt Vault**: To decrypt the vault file for viewing.
    ```bash
    make decrypt-vault
    ```

You will be prompted for the vault password when running playbooks that use vaulted variables.

## 🧩 Ansible Roles

-   **`proxmox_base`**: Configures the fundamental settings for Proxmox, including repositories, essential packages, NTP, and system performance tweaks.
-   **`vm_networking`**: Sets up a Linux bridge (`vmbr1`) for VMs, configures NAT for internet access, and applies basic firewall rules.
-   **`gpu_passthrough`**: Automates the configuration of IOMMU, kernel modules, and drivers to enable PCI passthrough of a GPU to a virtual machine.
-   **`common`**: Contains common tasks, such as validation checks, used across different playbooks.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any bugs, feature requests, or improvements.

1.  Fork the repository.
2.  Create a new feature branch (`git checkout -b feature/your-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin feature/your-feature`).
5.  Create a new Pull Request.

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
