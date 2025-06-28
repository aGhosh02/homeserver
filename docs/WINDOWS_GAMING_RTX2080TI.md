# Windows Gaming VM - RTX 2080 Ti Setup

This guide explains how to deploy a high-performance Windows Gaming VM with RTX 2080 Ti GPU passthrough using the exact specifications you requested.

## 🎯 Target Configuration

- **OS**: Windows 11 IoT Enterprise LTSC 2024
- **CPU**: 8 cores (host type, pinned to physical cores 0-7)
- **RAM**: 32GB (dedicated, no ballooning)
- **GPU**: RTX 2080 Ti with full passthrough + HDMI Audio
- **Features**: CPU host type, NUMA, PCIe ACS override, VirtIO drivers
- **ISOs**: 
  - Windows: https://drive.massgrave.dev/en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd_f6b14814.iso
  - VirtIO: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso

## 🚀 Quick Deployment

### Step 1: Find GPU PCI IDs

```bash
# Run the PCI ID detection script
./scripts/find-gpu-pci-ids.sh
```

This script will:
- Detect your RTX 2080 Ti
- Find the corresponding HDMI audio device
- Show IOMMU groups
- Provide configuration instructions

### Step 2: Deploy Windows Gaming VM

```bash
# Deploy with RTX 2080 Ti auto-detection
./scripts/deploy-windows-gaming-rtx2080ti.sh
```

Or use the general script with manual PCI IDs:

```bash
# Deploy with specific PCI IDs (update with your actual IDs)
./scripts/windows-gaming.sh --gpu 01:00.0 --audio 01:00.1 --memory 32768 --cores 8
```

## 📋 Prerequisites

### 1. BIOS/UEFI Configuration
- Enable **Intel VT-d** (Intel) or **AMD-Vi** (AMD)
- Enable **IOMMU** support
- Disable **CSM** (if using UEFI)

### 2. Proxmox Host Configuration

Add kernel parameters to enable IOMMU:

```bash
# Edit GRUB configuration
vim /etc/default/grub

# For Intel CPUs:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"

# For AMD CPUs:
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt pcie_acs_override=downstream,multifunction"

# Update GRUB and reboot
update-grub
reboot
```

### 3. Blacklist GPU Drivers

```bash
# Create blacklist file
cat >> /etc/modprobe.d/blacklist-gpu.conf << EOF
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
EOF

# Update initramfs
update-initramfs -u
reboot
```

## 🔧 Manual Configuration

If you need to manually configure PCI IDs, update these files:

### 1. Role Defaults (`ansible/roles/windows_gaming_vm/defaults/main.yml`)

```yaml
windows_vm:
  gpu_passthrough:
    enabled: true
    primary_gpu: "01:00.0"  # Your RTX 2080 Ti PCI ID
    gpu_audio: "01:00.1"    # Your RTX 2080 Ti Audio PCI ID
```

### 2. Playbook (`ansible/playbooks/deploy-windows-gaming.yml`)

```yaml
windows_vm:
  gpu_passthrough:
    enabled: true
    primary_gpu: "01:00.0"  # Your RTX 2080 Ti PCI ID
    gpu_audio: "01:00.1"    # Your RTX 2080 Ti Audio PCI ID
```

## 🎮 Post-Installation Setup

### 1. Windows Installation
1. Start the VM in Proxmox web interface
2. Connect monitor directly to RTX 2080 Ti
3. Install Windows 11 IoT Enterprise LTSC 2024
4. Install VirtIO drivers from mounted ISO

### 2. GPU Drivers and Optimization
1. Install latest NVIDIA GeForce drivers
2. Install MSI Afterburner for monitoring
3. Enable Windows Game Mode
4. Set power plan to High Performance
5. Configure NVIDIA Control Panel for gaming

### 3. Gaming Software
- Steam
- Epic Games Store
- Origin/EA App
- Battle.net
- Xbox Game Pass

## 📊 Performance Specifications

| Component | Specification | Notes |
|-----------|---------------|-------|
| CPU | 8 cores (host type) | Pinned to physical cores 0-7 |
| RAM | 32GB dedicated | No ballooning for consistent performance |
| GPU | RTX 2080 Ti passthrough | Full GPU access with HDMI audio |
| Storage | 100GB thick provisioned | Better I/O performance than thin |
| Network | VirtIO | High-performance network adapter |
| NUMA | Enabled | Better memory locality |
| Hugepages | Enabled | Reduced TLB misses |

## 🔍 Verification Commands

```bash
# Check IOMMU status
ls /sys/kernel/iommu_groups/

# Check GPU PCI IDs
lspci -nn | grep -i nvidia

# Check VFIO binding
lspci -k | grep -A 3 -i nvidia

# Check VM configuration
qm config <VM_ID>
```

## 🛠️ Troubleshooting

### GPU Not Detected
- Verify IOMMU is enabled: `dmesg | grep -i iommu`
- Check kernel parameters: `cat /proc/cmdline`
- Ensure GPU drivers are blacklisted: `lsmod | grep nvidia`

### VM Won't Start
- Check VM configuration: `qm config <VM_ID>`
- Verify GPU is bound to VFIO: `lspci -k`
- Check QEMU logs: `journalctl -u qemu-server@<VM_ID>`

### Performance Issues
- Enable hugepages: `echo 16384 > /proc/sys/vm/nr_hugepages`
- Set CPU governor: `cpupower frequency-set -g performance`
- Check CPU pinning: `qm config <VM_ID> | grep -i cpu`

## 📚 Additional Resources

- [Proxmox GPU Passthrough Guide](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [Windows 11 IoT LTSC](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-iot-enterprise-ltsc)
- [VirtIO Drivers](https://fedoraproject.org/wiki/Windows_Virtio_Drivers)
- [NVIDIA Driver Downloads](https://www.nvidia.com/drivers/)

---

**Happy Gaming with RTX 2080 Ti! 🎮**
