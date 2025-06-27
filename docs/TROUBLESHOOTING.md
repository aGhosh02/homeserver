# Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Proxmox homeserver automation.

## General Troubleshooting Steps

### 1. Check System Status
```bash
# Check overall system health
make validate

# Run comprehensive tests
make test

# Check logs
tail -f logs/ansible-*.log
```

### 2. Verify Configuration
```bash
# Check inventory
make inventory

# Test connectivity
make ping

# Gather system facts
make facts
```

### 3. Run Diagnostics
```bash
# System health check
./scripts/health-check.sh

# GPU passthrough diagnostics (if applicable)
./scripts/gpu-passthrough-manager.sh check
```

## Common Issues and Solutions

### Connectivity Issues

#### SSH Connection Refused
**Symptoms:**
- `ssh: connect to host X.X.X.X port 22: Connection refused`
- Ansible fails with "UNREACHABLE" error

**Solutions:**
1. **Verify SSH service is running:**
   ```bash
   # On Proxmox host
   systemctl status ssh
   systemctl start ssh  # if not running
   ```

2. **Check firewall settings:**
   ```bash
   # On Proxmox host
   iptables -L -n | grep :22
   ufw status  # if using ufw
   ```

3. **Verify SSH port:**
   ```bash
   # Check if SSH is on non-standard port
   netstat -tlnp | grep ssh
   ```

#### SSH Permission Denied
**Symptoms:**
- `Permission denied (publickey,password)`
- Authentication failures

**Solutions:**
1. **Check SSH key permissions:**
   ```bash
   chmod 600 ~/.ssh/id_rsa
   chmod 644 ~/.ssh/id_rsa.pub
   chmod 700 ~/.ssh/
   ```

2. **Verify SSH key is added:**
   ```bash
   ssh-add ~/.ssh/id_rsa
   ssh-add -l  # list loaded keys
   ```

3. **Test manual SSH connection:**
   ```bash
   ssh -i ~/.ssh/id_rsa root@YOUR_PROXMOX_IP
   ```

4. **Check authorized_keys on target:**
   ```bash
   # On Proxmox host
   cat ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

### Ansible Issues

#### Module Not Found
**Symptoms:**
- `ERROR! couldn't resolve module/action`
- Missing collection errors

**Solutions:**
1. **Install required collections:**
   ```bash
   make install-deps
   ```

2. **Verify collection installation:**
   ```bash
   ansible-galaxy collection list
   ```

3. **Check Ansible configuration:**
   ```bash
   ansible-config dump | grep COLLECTIONS_PATHS
   ```

#### Vault Decryption Failed
**Symptoms:**
- `ERROR! Decryption failed`
- Vault password prompts

**Solutions:**
1. **Verify vault password:**
   ```bash
   ansible-vault decrypt ansible/inventories/production/group_vars/all/vault.yml
   ```

2. **Check vault file format:**
   ```bash
   head -1 ansible/inventories/production/group_vars/all/vault.yml
   # Should start with $ANSIBLE_VAULT
   ```

3. **Re-encrypt vault file:**
   ```bash
   make encrypt-vault
   ```

### Proxmox Specific Issues

#### Repository Issues
**Symptoms:**
- Package installation failures
- Repository subscription errors

**Solutions:**
1. **Check repository configuration:**
   ```bash
   # On Proxmox host
   cat /etc/apt/sources.list
   cat /etc/apt/sources.list.d/pve-enterprise.list
   ```

2. **Update package lists:**
   ```bash
   # On Proxmox host
   apt update
   ```

3. **Remove enterprise repository (if not subscribed):**
   ```bash
   # This is handled by the playbook, but can be done manually:
   rm /etc/apt/sources.list.d/pve-enterprise.list
   ```

#### Kernel Module Issues
**Symptoms:**
- VFIO modules not loading
- GPU passthrough failures

**Solutions:**
1. **Check kernel modules:**
   ```bash
   # On Proxmox host
   lsmod | grep vfio
   lsmod | grep kvm
   ```

2. **Load modules manually:**
   ```bash
   # On Proxmox host
   modprobe vfio
   modprobe vfio_pci
   modprobe vfio_iommu_type1
   ```

3. **Check module configuration:**
   ```bash
   # On Proxmox host
   cat /etc/modules
   cat /etc/modprobe.d/blacklist.conf
   ```

### GPU Passthrough Issues

#### IOMMU Not Enabled
**Symptoms:**
- `/sys/kernel/iommu_groups/` directory doesn't exist
- GPU passthrough validation fails

**Solutions:**
1. **Check BIOS/UEFI settings:**
   - Enable VT-d (Intel) or AMD-Vi (AMD)
   - Enable IOMMU support

2. **Verify kernel parameters:**
   ```bash
   # On Proxmox host
   cat /proc/cmdline
   # Should contain intel_iommu=on or amd_iommu=on
   ```

3. **Update GRUB configuration:**
   ```bash
   # On Proxmox host
   vim /etc/default/grub
   # Add: GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
   update-grub
   reboot
   ```

#### GPU Not Binding to VFIO
**Symptoms:**
- GPU still bound to original driver
- VFIO binding fails

**Solutions:**
1. **Check current driver binding:**
   ```bash
   ./scripts/gpu-passthrough-manager.sh binding
   ```

2. **Manual GPU binding:**
   ```bash
   # Find your GPU PCI ID first
   lspci -nn | grep VGA
   
   # Bind to VFIO (replace with your PCI ID)
   ./scripts/gpu-passthrough-manager.sh bind 10de:2204
   ```

3. **Check blacklist configuration:**
   ```bash
   ./scripts/gpu-passthrough-manager.sh blacklist
   ```

### VM Creation Issues

#### Insufficient Resources
**Symptoms:**
- VM creation fails with resource errors
- Out of memory errors

**Solutions:**
1. **Check available resources:**
   ```bash
   # On Proxmox host
   free -h
   df -h
   pvesm status
   ```

2. **Adjust VM resource allocation:**
   ```yaml
   # In inventory or role defaults
   haos_memory: 1024  # Reduce if needed
   haos_cores: 1      # Reduce if needed
   ```

#### Storage Issues
**Symptoms:**
- Disk creation failures
- Storage not found errors

**Solutions:**
1. **Check storage configuration:**
   ```bash
   # On Proxmox host
   pvesm status
   cat /etc/pve/storage.cfg
   ```

2. **Verify disk space:**
   ```bash
   # On Proxmox host
   df -h /var/lib/vz
   ```

### Network Issues

#### Bridge Interface Not Created
**Symptoms:**
- vmbr1 interface missing
- Network connectivity issues for VMs

**Solutions:**
1. **Check interface configuration:**
   ```bash
   # On Proxmox host
   ip addr show
   cat /etc/network/interfaces
   ```

2. **Restart networking:**
   ```bash
   # On Proxmox host
   systemctl restart networking
   # Or reboot if needed
   ```

3. **Manual bridge creation:**
   ```bash
   # On Proxmox host
   ip link add name vmbr1 type bridge
   ip addr add 10.0.100.1/24 dev vmbr1
   ip link set vmbr1 up
   ```

#### NAT/Internet Access Issues
**Symptoms:**
- VMs can't access internet
- DNS resolution failures in VMs

**Solutions:**
1. **Check iptables rules:**
   ```bash
   # On Proxmox host
   iptables -t nat -L
   iptables -L FORWARD
   ```

2. **Verify IP forwarding:**
   ```bash
   # On Proxmox host
   cat /proc/sys/net/ipv4/ip_forward
   # Should be 1
   echo 1 > /proc/sys/net/ipv4/ip_forward
   ```

3. **Test connectivity from host:**
   ```bash
   # On Proxmox host
   ping -I vmbr1 8.8.8.8
   ```

## Performance Issues

### Slow Ansible Execution
**Symptoms:**
- Long deployment times
- Timeout errors

**Solutions:**
1. **Increase parallel execution:**
   ```ini
   # In ansible.cfg
   forks = 20
   ```

2. **Enable SSH pipelining:**
   ```ini
   # In ansible.cfg
   pipelining = True
   ```

3. **Use fact caching:**
   ```ini
   # In ansible.cfg
   fact_caching = jsonfile
   fact_caching_connection = /tmp/ansible_facts_cache
   ```

### High Resource Usage
**Symptoms:**
- System slowdowns
- Out of memory errors

**Solutions:**
1. **Monitor resource usage:**
   ```bash
   htop
   iostat
   iotop
   ```

2. **Adjust VM resource allocation:**
   ```yaml
   # Reduce resource allocation if needed
   haos_memory: 1024
   haos_cores: 1
   ```

3. **Optimize storage:**
   ```bash
   # Use SSD storage for better performance
   # Enable write caching (if safe)
   ```

## Debugging Techniques

### Enable Verbose Logging
```bash
# Run with maximum verbosity
cd ansible
ansible-playbook playbooks/site.yml -vvv

# Check specific task
ansible-playbook playbooks/site.yml --start-at-task="Task Name" -vvv
```

### Run Specific Tags
```bash
# Test specific functionality
make run --tags base
make run --tags networking
make run --tags gpu
```

### Check Individual Tasks
```bash
# Run single role
cd ansible
ansible-playbook -i inventories/production roles/proxmox_base/tests/test.yml
```

### Manual Task Execution
```bash
# Run ad-hoc commands
cd ansible
ansible all -m ping
ansible all -m setup
ansible all -m shell -a "systemctl status ssh"
```

## Log Analysis

### Important Log Locations
```bash
# Ansible logs
tail -f logs/ansible-*.log

# System logs (on Proxmox host)
tail -f /var/log/syslog
tail -f /var/log/daemon.log
tail -f /var/log/kern.log

# Proxmox specific logs
tail -f /var/log/pve-firewall.log
tail -f /var/log/pveproxy/access.log
```

### Log Analysis Commands
```bash
# Search for errors
grep -i error logs/ansible-*.log

# Check task execution times
grep "TASK\|ok:\|failed:" logs/ansible-*.log

# Find connection issues
grep -i "unreachable\|timeout\|connection" logs/ansible-*.log
```

## Getting Additional Help

### Gather System Information
```bash
# Create diagnostic report
./scripts/health-check.sh > diagnostic-report.txt

# Gather Ansible facts
make facts

# System information
cd ansible
ansible all -m setup --tree /tmp/facts
```

### Community Resources
- [Proxmox VE Wiki](https://pve.proxmox.com/wiki/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Proxmox Community Forum](https://forum.proxmox.com/)

### Creating Issues
When reporting issues, please include:
1. **System Information**: OS, Ansible version, Proxmox version
2. **Error Messages**: Complete error output
3. **Configuration**: Relevant configuration files (sanitized)
4. **Steps to Reproduce**: Exact commands and steps
5. **Expected Behavior**: What should have happened
6. **Actual Behavior**: What actually happened

### Emergency Recovery
If the system becomes unresponsive:
1. **Console Access**: Use IPMI or physical console
2. **Network Recovery**: Reset network configuration
3. **Service Recovery**: Restart critical services
4. **Backup Restore**: Restore from known good backup

Remember: Always test changes in a non-production environment first!
