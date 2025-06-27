# OpenMediaVault NAS VM Deployment Guide

This guide covers the automated deployment of OpenMediaVault NAS VM on Proxmox VE using Ansible.

## 📋 Overview

The OpenMediaVault VM deployment provides:
- **Pre-configured NAS VM**: 2 vCPUs (shared), 4GB RAM, 32GB disk
- **Disk Passthrough**: Direct HDD access via SATA controller
- **Optimized Configuration**: Balloon memory disabled for stable performance
- **Automated Installation**: ISO download and VM setup

## 🔧 VM Specifications

| Component | Specification | Notes |
|-----------|---------------|-------|
| **CPU** | 2 cores (shared) | Host CPU type for best performance |
| **Memory** | 4GB | Balloon disabled for NAS stability |
| **Primary Disk** | 32GB | System installation disk |
| **Storage Disks** | Configurable | Passthrough via SATA controller |
| **Network** | vmbr0 | Default bridge, customizable |
| **BIOS** | OVMF | UEFI for modern compatibility |

## 🚀 Quick Deployment

### Basic Deployment
```bash
# Using Make
make deploy-omv

# Using Script
./scripts/omv.sh

# Using Ansible directly
cd ansible
ansible-playbook playbooks/deploy-omv.yml
```

### With Disk Passthrough
```bash
# Script with disk passthrough
./scripts/omv.sh --disks sdb,sdc

# Ansible with extra variables
cd ansible
ansible-playbook playbooks/deploy-omv.yml -e "omv_vm.nas_storage.passthrough_disks=['sdb','sdc']"
```

### Custom Configuration
```bash
# Custom resources and hostname
./scripts/omv.sh --memory 8192 --cores 4 --hostname nas-server

# Force deployment (overwrite existing)
./scripts/omv.sh --force
```

## ⚙️ Configuration Options

### Basic VM Configuration
```yaml
omv_vm:
  hostname: "openmediavault"
  disk_size: "32G"
  
  cpu:
    type: "host"
    cores: 2
  memory: 4096  # 4GB in MB
  
  # Disable balloon for NAS stability
  balloon: false
```

### Network Configuration
```yaml
omv_vm:
  network:
    bridge: "vmbr0"
    mac_address: ""  # Auto-generated
    vlan_tag: ""
    mtu: ""
```

### Storage and Passthrough
```yaml
omv_vm:
  nas_storage:
    # List of disks to passthrough (by device name)
    passthrough_disks: ["sdb", "sdc", "sdd"]
    # Enable SATA controller for passthrough
    sata_controller: true
  
  storage:
    location: ""  # Auto-detected Proxmox storage
    cache: "writethrough"
    thin_provisioning: true
```

### Download Configuration
```yaml
omv_download:
  iso_url: "https://sourceforge.net/projects/openmediavault/files/iso/7.4.17/openmediavault_7.4.17-amd64.iso"
  version: "7.4.17"
  timeout: 600  # 10 minutes
```

## 🗄️ Disk Passthrough Configuration

### Identifying Available Disks
```bash
# List all block devices
lsblk

# List disks with detailed info
fdisk -l

# Check disk usage
df -h
mount | grep /dev/sd
```

### Passthrough Configuration
```yaml
omv_vm:
  nas_storage:
    passthrough_disks:
      - "sdb"  # Second SATA disk
      - "sdc"  # Third SATA disk
      - "sdd"  # Fourth SATA disk
```

### Important Notes for Disk Passthrough
- ⚠️ **Unmount disks** before passthrough
- 🔒 **Host loses access** to passed-through disks
- 💾 **Use by-id paths** for stability (automatic)
- 🗄️ **SATA ports assignment**: sata1, sata2, etc.

## 📦 Installation Process

### 1. Automated VM Creation
```bash
./scripts/omv.sh
```
The script will:
- ✅ Download OpenMediaVault ISO
- ✅ Create VM with specified configuration
- ✅ Configure SATA controller and disk passthrough
- ✅ Attach ISO and set boot order
- ✅ Start VM (optional)

### 2. Manual Installation Steps
1. **Access VM Console** in Proxmox web interface
2. **Boot from ISO** and follow OpenMediaVault installer
3. **Configure basic settings**:
   - Language and timezone
   - Network configuration
   - User accounts
4. **Complete installation** and reboot
5. **Remove ISO** from VM configuration
6. **Change boot order** to boot from disk

### 3. Post-Installation Configuration
1. **Access Web Interface**: `http://VM_IP`
2. **Default Login**: `admin` / `openmediavault`
3. **Configure Storage**:
   - Add physical disks
   - Create RAID arrays if needed
   - Set up filesystems
4. **Configure Services**:
   - SMB/CIFS shares
   - NFS exports
   - FTP services
   - RSYNC jobs

## 🔧 Management Commands

### VM Operations
```bash
# Start/Stop VM
qm start VM_ID
qm stop VM_ID

# VM configuration
qm config VM_ID
qm set VM_ID -description "Updated description"

# Add disk manually
qm set VM_ID -sata2 /dev/disk/by-id/DISK_ID
```

### Deployment Options
```bash
# Check deployment (dry-run)
make deploy-omv-check

# Force deployment
make deploy-omv-force

# Script options
./scripts/omv.sh --help
```

## 🚨 Troubleshooting

### Common Issues

#### VM Creation Fails
```bash
# Check Proxmox storage
pvesm status

# Check available VM IDs
qm list

# Check logs
tail -f /var/log/daemon.log
```

#### ISO Download Fails
```bash
# Check internet connectivity
ping 8.8.8.8

# Manual download
wget "https://sourceforge.net/projects/openmediavault/files/iso/7.4.17/openmediavault_7.4.17-amd64.iso"

# Check firewall
iptables -L
```

#### Disk Passthrough Issues
```bash
# Check disk exists
ls -la /dev/sdb

# Check disk not mounted
mount | grep /dev/sdb

# Check disk by-id
ls -la /dev/disk/by-id/ | grep sdb

# SATA controller info
qm config VM_ID | grep sata
```

#### Network Issues
```bash
# Check bridge
ip link show vmbr0

# Check VM network
qm config VM_ID | grep net

# Test connectivity from VM
# (access VM console and ping gateway)
```

### Error Messages

#### "Storage location could not be determined"
**Solution**: Specify storage explicitly
```bash
./scripts/omv.sh -e "omv_vm.storage.location=local-lvm"
```

#### "Disk /dev/sdX appears to be mounted"
**Solution**: Unmount disk before passthrough
```bash
umount /dev/sdX
```

#### "VM ID already exists"
**Solution**: Use force flag or specify different ID
```bash
./scripts/omv.sh --force
```

## 📊 Performance Optimization

### VM Settings
```yaml
omv_vm:
  # Disable balloon for consistent memory
  balloon: false
  
  # Use host CPU for best performance
  cpu:
    type: "host"
  
  # Writethrough cache for data integrity
  storage:
    cache: "writethrough"
```

### Host Optimizations
```bash
# Increase dirty page timeout for better write performance
echo 'vm.dirty_expire_centisecs = 3000' >> /etc/sysctl.conf

# Optimize for storage workloads
echo 'vm.swappiness = 10' >> /etc/sysctl.conf
```

## 🔒 Security Considerations

### Network Security
- Configure firewall rules for NAS access only
- Use VLANs to isolate NAS traffic
- Enable encryption for remote access

### Storage Security
- Use RAID for redundancy
- Configure regular backups
- Encrypt sensitive shares

### Access Control
- Change default passwords immediately
- Use strong authentication
- Implement access logging

## 📚 Additional Resources

### OpenMediaVault Documentation
- [Official Documentation](https://docs.openmediavault.org/)
- [Community Forum](https://forum.openmediavault.org/)
- [Plugin Repository](https://www.openmediavault.org/plugins.html)

### Proxmox Resources
- [VM Management](https://pve.proxmox.com/wiki/Qemu/KVM_Virtual_Machines)
- [Storage Configuration](https://pve.proxmox.com/wiki/Storage)
- [Disk Passthrough](https://pve.proxmox.com/wiki/Passthrough)

### Troubleshooting Resources
- Check deployment logs: `/var/log/ansible-deployment/`
- Proxmox logs: `/var/log/daemon.log`
- VM console: Proxmox web interface → VM → Console
