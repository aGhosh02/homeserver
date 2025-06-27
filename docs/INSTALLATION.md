# Installation Guide

This guide provides detailed instructions for setting up and deploying the Proxmox homeserver automation.

## Prerequisites

### System Requirements

#### Control Machine (Ansible Host)
- **OS**: Linux, macOS, or WSL2 on Windows
- **Python**: 3.8 or higher
- **Ansible**: 2.12 or higher
- **Memory**: 2GB RAM minimum
- **Storage**: 1GB free space
- **Network**: SSH access to Proxmox hosts

#### Target Machine (Proxmox Host)
- **OS**: Proxmox VE 7.x or 8.x
- **CPU**: Intel VT-x/VT-d or AMD-V/AMD-Vi (for virtualization)
- **Memory**: 8GB RAM minimum (16GB+ recommended)
- **Storage**: 100GB minimum (SSD recommended)
- **Network**: Static IP address configured
- **Access**: SSH root access or sudo user

### Software Dependencies

1. **Install Ansible** (on control machine):
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install ansible python3-pip git
   
   # CentOS/RHEL/Fedora
   sudo dnf install ansible python3-pip git
   
   # macOS
   brew install ansible git
   
   # Python pip (universal)
   pip3 install ansible
   ```

2. **Verify Installation**:
   ```bash
   ansible --version
   git --version
   ```

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/your-repo/homeserver.git
cd homeserver
```

### 2. Check Dependencies

```bash
make check-deps
```

This will verify that all required tools are installed and meet minimum version requirements.

### 3. Initial Setup

```bash
make setup
```

This command will:
- Install required Ansible collections
- Create necessary directories
- Set up the project structure

### 4. Configure Inventory

Edit the inventory file with your Proxmox server details:

```bash
vi ansible/inventories/production/hosts.yml
```

**Minimum required changes**:
```yaml
proxmox:
  hosts:
    pve:
      ansible_host: YOUR_PROXMOX_IP
      ansible_user: root
      # Choose one authentication method:
      ansible_ssh_pass: "{{ vault_ssh_password }}"  # From vault
      # OR
      ansible_ssh_private_key_file: ~/.ssh/id_rsa    # SSH key
```

### 5. Configure Variables

Review and customize the configuration variables:

```bash
# Main configuration
vi ansible/inventories/production/group_vars/proxmox.yml

# Sensitive data (create vault)
make edit-vault
```

### 6. Test Connectivity

```bash
make validate
```

This will test SSH connectivity and gather basic system information.

### 7. Deploy

```bash
# Dry run first (recommended)
make dry-run

# Full deployment
make run
```

## Detailed Configuration

### SSH Authentication Setup

#### Option 1: SSH Key Authentication (Recommended)

1. **Generate SSH key** (if you don't have one):
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
   ```

2. **Copy key to Proxmox host**:
   ```bash
   ssh-copy-id root@YOUR_PROXMOX_IP
   ```

3. **Update inventory**:
   ```yaml
   ansible_ssh_private_key_file: ~/.ssh/id_rsa
   ```

#### Option 2: Password Authentication

1. **Create vault file**:
   ```bash
   make edit-vault
   ```

2. **Add password to vault**:
   ```yaml
   vault_ssh_password: "your-secure-password"
   ```

3. **Update inventory**:
   ```yaml
   ansible_ssh_pass: "{{ vault_ssh_password }}"
   ```

### Network Configuration

Configure network settings in `group_vars/proxmox.yml`:

```yaml
network_config:
  vm_bridge:
    name: vmbr1
    address: 10.0.100.1
    netmask: 255.255.255.0
    network: 10.0.100.0/24
    gateway: 10.0.200.1
    
  nat_config:
    enabled: true
    external_interface: vmbr0
    internal_interface: vmbr1
    internal_network: 10.0.100.0/24
```

### GPU Passthrough Configuration

For GPU passthrough, configure the GPU settings:

```yaml
gpu_passthrough:
  enabled: true
  iommu:
    kernel_params: "intel_iommu=on iommu=pt"  # Intel
    # kernel_params: "amd_iommu=on iommu=pt"  # AMD
    
  gpu_config:
    auto_detect: true
    # Manual configuration if auto_detect fails:
    pci_ids:
      - "10de:2204"  # Your GPU PCI ID
      - "10de:1aef"  # Your GPU Audio PCI ID
```

### Home Assistant OS VM

Configure HAOS VM deployment:

```yaml
haos_vm:
  enabled: true
  vm_id: 100
  memory: 2048
  cores: 2
  disk_size: 32
  network_bridge: vmbr1
  start_on_boot: true
```

## Deployment Options

### Full Deployment

Deploy all components:
```bash
make run
```

### Selective Deployment

Deploy specific components:
```bash
make run-base      # Base system only
make run-network   # Network configuration only
make run-gpu       # GPU passthrough only
make deploy-haos   # Home Assistant OS only
```

### Development/Testing

For development and testing:
```bash
make dry-run       # Simulate changes
make validate      # Test connectivity
make lint          # Check code quality
make test          # Run all tests
```

## Post-Installation

### 1. Verify Installation

```bash
make validate
```

### 2. Check System Status

```bash
# Run health check script
./scripts/health-check.sh

# Check GPU passthrough (if enabled)
./scripts/gpu-passthrough-manager.sh check
```

### 3. Access Services

- **Proxmox Web Interface**: https://YOUR_PROXMOX_IP:8006
- **Home Assistant** (if deployed): http://VM_IP:8123

### 4. Create Backups

```bash
make backup
```

## Troubleshooting

### Common Issues

#### 1. SSH Connection Failed
```bash
# Test manual SSH connection
ssh root@YOUR_PROXMOX_IP

# Check SSH service
systemctl status ssh
```

#### 2. Ansible Command Not Found
```bash
# Install Ansible
pip3 install ansible

# Or use system package manager
sudo apt install ansible
```

#### 3. Permission Denied
```bash
# Check user permissions
sudo -l

# Verify SSH key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

#### 4. GPU Passthrough Issues
```bash
# Check IOMMU status
./scripts/gpu-passthrough-manager.sh iommu

# Verify VFIO binding
./scripts/gpu-passthrough-manager.sh binding
```

### Getting Help

1. **Check logs**:
   ```bash
   tail -f logs/ansible-*.log
   ```

2. **Run with verbose output**:
   ```bash
   cd ansible
   ansible-playbook playbooks/site.yml -vvv
   ```

3. **Test individual components**:
   ```bash
   make run-base --tags validation
   ```

## Security Considerations

### 1. SSH Security
- Use SSH keys instead of passwords
- Change default SSH port if needed
- Enable fail2ban for brute force protection

### 2. Vault Security
- Use strong vault passwords
- Store vault password securely
- Never commit unencrypted sensitive data

### 3. Network Security
- Configure firewall rules appropriately
- Use network segmentation
- Regular security updates

### 4. System Hardening
- Disable unnecessary services
- Configure log rotation
- Monitor system access

## Next Steps

After successful installation:

1. **Configure Monitoring**: Set up monitoring and alerting
2. **Plan Backups**: Implement backup strategies
3. **Document Changes**: Keep track of customizations
4. **Test Disaster Recovery**: Verify backup and restore procedures
5. **Security Hardening**: Implement additional security measures

For more detailed information, see:
- [Architecture Documentation](ARCHITECTURE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Best Practices](BEST_PRACTICES.md)
