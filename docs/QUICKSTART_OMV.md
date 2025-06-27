# OpenMediaVault VM Deployment - Quick Start

## 🎯 Overview

This deployment creates an OpenMediaVault NAS VM with the following specifications:
- **CPU**: 2 cores (shared)
- **RAM**: 4GB (balloon disabled)
- **Disk**: 32GB system disk + passthrough HDDs
- **Network**: Default bridge (vmbr0)
- **Features**: SATA controller for disk passthrough

## 🚀 Quick Deployment

### Option 1: Using the Deployment Script (Recommended)
```bash
# Basic deployment
./scripts/omv.sh

# With disk passthrough
./scripts/omv.sh --disks sdb,sdc

# Custom configuration
./scripts/omv.sh --memory 8192 --cores 4 --hostname nas-server
```

### Option 2: Using Make
```bash
# Basic deployment
make deploy-omv

# Check deployment (dry-run)
make deploy-omv-check

# Force deployment (overwrite existing)
make deploy-omv-force
```

### Option 3: Using Ansible Directly
```bash
cd ansible

# Basic deployment
ansible-playbook playbooks/deploy-omv.yml

# With custom variables
ansible-playbook playbooks/deploy-omv.yml -e "omv_vm.memory=8192"

# With disk passthrough
ansible-playbook playbooks/deploy-omv.yml -e "omv_vm.nas_storage.passthrough_disks=['sdb','sdc']"
```

## ⚙️ Configuration Examples

### Basic Configuration
```yaml
omv_vm:
  hostname: "openmediavault"
  memory: 4096  # 4GB
  cpu:
    cores: 2
  balloon: false  # Disabled for NAS stability
```

### With Disk Passthrough
```yaml
omv_vm:
  nas_storage:
    passthrough_disks: ["sdb", "sdc", "sdd"]
    sata_controller: true
```

## 📝 Post-Deployment Steps

1. **Access Proxmox Web UI**: `https://your-proxmox-ip:8006`
2. **Start the VM** (if not auto-started)
3. **Open VM Console** and follow OpenMediaVault installation
4. **After installation**:
   - Remove ISO from VM
   - Change boot order to disk
   - Access OMV Web UI: `http://vm-ip`
   - Default login: `admin` / `openmediavault`

## 🔧 Customization Options

### Script Options
```bash
./scripts/omv.sh --help
```

Available options:
- `--disks sdb,sdc` - Disk passthrough
- `--memory 8192` - Custom memory (MB)
- `--cores 4` - Custom CPU cores
- `--hostname name` - Custom hostname
- `--force` - Force deployment
- `--verbose` - Verbose output
- `--check` - Dry-run mode

### Ansible Variables
```yaml
omv_vm:
  hostname: "custom-nas"
  memory: 8192
  cpu:
    cores: 4
  disk_size: "64G"
  nas_storage:
    passthrough_disks: ["sdb", "sdc"]
```

## 🚨 Important Notes

- **Disk Passthrough**: Ensure disks are unmounted before passthrough
- **Memory Balloon**: Disabled by default for NAS stability
- **SATA Controller**: Automatically configured for disk passthrough
- **ISO Download**: Automatically downloads OpenMediaVault 7.4.17 ISO

## 📚 Documentation

- **Detailed Guide**: `docs/OMV_DEPLOYMENT.md`
- **Troubleshooting**: Check the detailed guide for common issues
- **OpenMediaVault Docs**: https://docs.openmediavault.org/
