# Best Practices Guide

This guide outlines recommended practices for deploying, configuring, and maintaining your Proxmox homeserver using this automation suite.

## 🏗️ Infrastructure Planning

### Hardware Considerations

#### CPU Requirements
- **Minimum**: 4 cores with virtualization support (VT-x/VT-d or AMD-V/AMD-Vi)
- **Recommended**: 8+ cores for multiple VMs
- **GPU Passthrough**: Ensure IOMMU support is available

#### Memory Planning
```
Base Proxmox Host: 4-8GB
+ Each VM: 1-16GB (depending on purpose)
+ Buffer: 2-4GB
= Total Required Memory
```

#### Storage Strategy
- **System Drive**: SSD for Proxmox OS (100GB minimum)
- **VM Storage**: Separate SSD/NVMe for VM images (500GB+)
- **Backup Storage**: Additional drive for backups
- **Network Storage**: Consider NAS for larger deployments

### Network Architecture

#### Recommended Network Topology
```
Internet
    │
Router/Firewall
    │
Management Network (vmbr0)
    │
Proxmox Host
    │
VM Network (vmbr1)
    │
Virtual Machines
```

#### IP Address Planning
- **Management Network**: 10.0.200.0/24
- **VM Network**: 10.0.100.0/24
- **Services Network**: 10.0.110.0/24 (optional)

## 🔒 Security Best Practices

### Authentication and Access

#### SSH Security
```bash
# Use SSH keys instead of passwords
ssh-keygen -t rsa -b 4096 -C "homeserver-management"

# Disable password authentication
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Use non-standard SSH port (optional)
echo "Port 2222" >> /etc/ssh/sshd_config
```

#### Ansible Vault
```bash
# Create vault password file
echo "your-secure-vault-password" > ~/.ansible/vault_pass
chmod 600 ~/.ansible/vault_pass

# Encrypt sensitive data
ansible-vault encrypt_string "sensitive-value" --name "variable_name"
```

### Firewall Configuration

#### Host-level Firewall
```bash
# Basic iptables rules for Proxmox
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT    # SSH
iptables -A INPUT -p tcp --dport 8006 -j ACCEPT  # Proxmox Web UI
iptables -A INPUT -j DROP
```

#### VM Network Isolation
- Separate VM networks by function
- Use VLANs for additional isolation
- Implement proper firewall rules between networks

### System Hardening

#### Proxmox Specific
- Disable unused services
- Regular security updates
- Monitor system logs
- Use fail2ban for SSH protection

#### VM Security
- Regular VM updates
- Minimal service exposure
- Network segmentation
- Backup encryption

## 📊 Performance Optimization

### System Tuning

#### Kernel Parameters
```bash
# Add to /etc/sysctl.conf for better virtualization performance
vm.swappiness = 10
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
```

#### CPU Optimization
- Enable CPU governor for performance
- Set appropriate CPU affinity for VMs
- Use host CPU type for better performance

#### Memory Management
- Configure appropriate RAM allocation
- Enable memory ballooning for dynamic allocation
- Monitor memory usage regularly

### Storage Performance

#### SSD Optimization
```bash
# Enable TRIM support
echo 'ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="deadline"' > /etc/udev/rules.d/60-ssd-scheduler.rules

# Configure mount options
echo "UUID=your-ssd-uuid /var/lib/vz ext4 defaults,noatime,discard 0 2" >> /etc/fstab
```

#### VM Storage Configuration
- Use virtio-scsi for better performance
- Enable write-back caching for development VMs
- Use write-through caching for production VMs

### Network Performance

#### Bridge Configuration
```bash
# Optimize network bridges
echo 'net.bridge.bridge-nf-call-iptables = 0' >> /etc/sysctl.conf
echo 'net.bridge.bridge-nf-call-ip6tables = 0' >> /etc/sysctl.conf
```

#### VM Network Settings
- Use virtio network drivers
- Enable multiqueue for high-throughput VMs
- Consider SR-IOV for performance-critical workloads

## 🔄 Backup and Recovery

### Backup Strategy

#### 3-2-1 Backup Rule
- **3** copies of important data
- **2** different storage media
- **1** offsite backup

#### Proxmox Backup Schedule
```bash
# Weekly full backup
vzdump --compress lzo --mode snapshot --all 1

# Daily incremental backup
vzdump --compress lzo --mode snapshot --all 1 --node $(hostname)
```

### Configuration Backup

#### Ansible Configuration
```bash
# Create configuration backup
make backup

# Store backup offsite
rsync -av backup-*.tar.gz user@backup-server:/backups/
```

#### Proxmox Configuration
```bash
# Backup Proxmox configuration
tar -czf /root/pve-config-$(date +%Y%m%d).tar.gz /etc/pve/

# Backup VM configurations
cp -r /etc/pve/qemu-server/ /root/vm-configs-backup/
```

### Disaster Recovery

#### Recovery Planning
1. **Document Recovery Procedures**
2. **Test Recovery Process Regularly**
3. **Maintain Recovery Media**
4. **Document Network Configuration**

#### Recovery Checklist
- [ ] Proxmox ISO and installation media
- [ ] Configuration backups
- [ ] Network configuration documentation
- [ ] VM backup files
- [ ] SSL certificates and keys

## 📈 Monitoring and Maintenance

### Health Monitoring

#### System Monitoring
```bash
# Use built-in health check
./scripts/health-check.sh

# Monitor system resources
htop
iotop
netstat -tulpn
```

#### Automated Monitoring
- Set up log rotation
- Monitor disk space usage
- Check service status regularly
- Monitor VM resource usage

### Regular Maintenance

#### Weekly Tasks
- [ ] Check system logs
- [ ] Verify backup completion
- [ ] Update system packages
- [ ] Check disk space usage

#### Monthly Tasks
- [ ] Review security logs
- [ ] Update documentation
- [ ] Test disaster recovery
- [ ] Clean up old files

#### Quarterly Tasks
- [ ] Security audit
- [ ] Performance review
- [ ] Hardware health check
- [ ] Update recovery procedures

### Log Management

#### Centralized Logging
```bash
# Configure rsyslog for centralized logging
echo "*.* @@log-server:514" >> /etc/rsyslog.conf
systemctl restart rsyslog
```

#### Log Rotation
```bash
# Configure logrotate
cat > /etc/logrotate.d/proxmox-custom << EOF
/var/log/pve-firewall.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
EOF
```

## 🚀 Deployment Best Practices

### Pre-deployment

#### Planning Phase
1. **Document Requirements**: Hardware, network, services
2. **Design Network Architecture**: IP ranges, VLANs, security zones
3. **Plan Resource Allocation**: CPU, memory, storage per VM
4. **Prepare Recovery Plan**: Backup and disaster recovery procedures

#### Testing Phase
```bash
# Always test in dry-run mode first
make dry-run

# Validate configuration
make config-validate

# Test connectivity
make ping
```

### Deployment Process

#### Step-by-Step Deployment
1. **Infrastructure Setup**
   ```bash
   make setup
   make config-validate
   ```

2. **Base System Configuration**
   ```bash
   make run-base
   make validate
   ```

3. **Network Configuration**
   ```bash
   make run-network
   make network-test
   ```

4. **Service Deployment**
   ```bash
   make deploy-haos
   make validate
   ```

#### Rollback Procedures
- Maintain configuration backups
- Document rollback steps
- Test rollback procedures
- Keep previous working configurations

### Post-deployment

#### Validation Checklist
- [ ] All services running correctly
- [ ] Network connectivity working
- [ ] Backup systems operational
- [ ] Monitoring systems active
- [ ] Documentation updated

#### Optimization Phase
- Monitor performance metrics
- Adjust resource allocation
- Optimize network configuration
- Fine-tune security settings

## 🔧 VM Management Best Practices

### VM Templates

#### Creating Templates
```bash
# Create VM template for common configurations
qm create 9000 --name "ubuntu-template" --memory 1024 --cores 1
qm importdisk 9000 ubuntu-20.04-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

#### Template Maintenance
- Regular template updates
- Security patch management
- Documentation of template configurations

### Resource Management

#### CPU Allocation
- Don't over-allocate CPU cores
- Use CPU limits for non-critical VMs
- Consider NUMA topology for large VMs

#### Memory Management
- Enable memory ballooning
- Set appropriate memory limits
- Monitor memory usage patterns

#### Storage Management
- Use thin provisioning when appropriate
- Regular storage cleanup
- Monitor storage performance

## 🌐 Networking Best Practices

### Network Segmentation

#### VLAN Configuration
```bash
# Configure VLAN-aware bridge
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
```

#### Firewall Rules
- Implement default-deny policies
- Use specific rules for required access
- Regular firewall rule audits
- Document firewall changes

### DNS and DHCP

#### Internal DNS
- Use internal DNS for better performance
- Implement split-horizon DNS
- Regular DNS record cleanup

#### DHCP Configuration
- Use DHCP reservations for servers
- Configure appropriate lease times
- Monitor DHCP pool usage

## 📚 Documentation Standards

### Configuration Documentation

#### Required Documentation
- Network diagram and IP allocations
- Service configurations and dependencies
- Backup and recovery procedures
- Troubleshooting guides

#### Documentation Format
- Use markdown for consistency
- Include code examples
- Maintain version control
- Regular documentation reviews

### Change Management

#### Change Documentation
- Document all configuration changes
- Maintain change logs
- Include rollback procedures
- Test documentation accuracy

#### Version Control
- Use git for configuration management
- Tag releases appropriately
- Maintain development branches
- Regular repository cleanup

## 🎯 Troubleshooting Best Practices

### Systematic Approach

#### Problem Resolution Process
1. **Identify**: Clearly define the problem
2. **Isolate**: Determine scope and impact
3. **Investigate**: Gather relevant information
4. **Implement**: Apply appropriate solutions
5. **Verify**: Confirm resolution
6. **Document**: Record solution for future reference

#### Information Gathering
```bash
# System information
./scripts/health-check.sh > problem-report.txt

# Network diagnostics
ip addr show >> problem-report.txt
ip route show >> problem-report.txt

# Service status
systemctl status --all >> problem-report.txt
```

### Common Issues

#### Performance Problems
- Check resource utilization
- Review system logs
- Analyze network traffic
- Monitor storage I/O

#### Connectivity Issues
- Verify network configuration
- Check firewall rules
- Test DNS resolution
- Validate routing tables

## 🔄 Continuous Improvement

### Regular Reviews

#### Performance Reviews
- Monthly performance analysis
- Resource utilization trends
- Capacity planning updates
- Performance optimization opportunities

#### Security Reviews
- Quarterly security audits
- Vulnerability assessments
- Access control reviews
- Security policy updates

### Community Engagement

#### Contributing Back
- Share improvements with community
- Report bugs and feature requests
- Contribute to documentation
- Help other users

#### Staying Updated
- Follow project updates
- Subscribe to security notifications
- Participate in community discussions
- Regular training and learning

Remember: The key to successful homeserver management is consistency, documentation, and continuous learning. Start with the basics and gradually implement more advanced practices as you gain experience.
