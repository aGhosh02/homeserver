# Proxmox Homeserver Ansible Setup

![Ansible Lint](https://github.com/actions/workflow_run?workflow=ansible-lint)
[![Made with Ansible](https://img.shields.io/badge/Made%20with-Ansible-red.svg)](https://www.ansible.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository contains a set of Ansible playbooks and roles to automate the setup and configuration of a Proxmox VE homeserver. It is designed to be idempotent and modular, allowing you to easily manage your Proxmox environment from a central location.

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
