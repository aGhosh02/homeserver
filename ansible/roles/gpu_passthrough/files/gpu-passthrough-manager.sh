#!/bin/bash

# GPU Passthrough Management Script for Proxmox
# This script helps with GPU passthrough configuration and troubleshooting

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_iommu() {
    print_header "IOMMU Status Check"
    
    if [ -d "/sys/kernel/iommu_groups" ]; then
        print_success "IOMMU is enabled"
        
        echo -e "\nIOMMU Groups for GPU devices:"
        for d in /sys/kernel/iommu_groups/*/devices/*; do
            n=${d#*/iommu_groups/*}; n=${n%%/*}
            printf 'Group %s: ' "$n"
            lspci -nns "${d##*/}"
        done | grep -E "(VGA|Audio|3D)" | sort -V || print_warning "No GPU devices found in IOMMU groups"
    else
        print_error "IOMMU is not enabled"
        echo "Add 'intel_iommu=on' (Intel) or 'amd_iommu=on' (AMD) to GRUB_CMDLINE_LINUX in /etc/default/grub"
    fi
}

detect_gpu() {
    print_header "GPU Detection"
    
    echo "Detected GPU devices:"
    lspci -nn | grep -E "(VGA|Audio|3D)" | grep -E "(NVIDIA|AMD|Intel)" | while read line; do
        pci_slot=$(echo "$line" | awk '{print $1}')
        pci_id=$(echo "$line" | grep -o '\[.*\]' | tail -1 | tr -d '[]')
        echo "  PCI Slot: $pci_slot, PCI ID: $pci_id"
        echo "  Device: $line"
        echo ""
    done
}

check_vfio() {
    print_header "VFIO Driver Status"
    
    if lsmod | grep -q vfio_pci; then
        print_success "VFIO PCI driver is loaded"
    else
        print_error "VFIO PCI driver is not loaded"
    fi
    
    echo -e "\nVFIO modules:"
    lsmod | grep vfio || print_warning "No VFIO modules loaded"
}

check_gpu_binding() {
    print_header "GPU Driver Binding Status"
    
    lspci -nn | grep -E "(VGA|Audio|3D)" | grep -E "(NVIDIA|AMD|Intel)" | while read line; do
        pci_slot=$(echo "$line" | awk '{print $1}')
        pci_id=$(echo "$line" | grep -o '\[.*\]' | tail -1 | tr -d '[]')
        
        driver=$(lspci -k -s "$pci_slot" | grep "Kernel driver in use:" | awk '{print $5}')
        
        echo "PCI ID: $pci_id, Slot: $pci_slot"
        if [ "$driver" = "vfio-pci" ]; then
            print_success "Bound to vfio-pci"
        elif [ -n "$driver" ]; then
            print_warning "Bound to: $driver (not vfio-pci)"
        else
            print_warning "No driver bound"
        fi
        echo ""
    done
}

check_blacklist() {
    print_header "Blacklisted Driver Status"
    
    blacklisted_drivers=("nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" "radeon" "amdgpu")
    
    for driver in "${blacklisted_drivers[@]}"; do
        if lsmod | grep -q "^$driver"; then
            print_error "$driver is loaded (should be blacklisted)"
        else
            print_success "$driver is not loaded"
        fi
    done
}

show_vm_config_example() {
    print_header "VM Configuration Example"
    
    cat << 'EOF'
Example VM configuration for GPU passthrough:

1. VM Settings in Proxmox Web UI:
   - Machine: q35
   - BIOS: OVMF (UEFI)
   - CPU Type: host
   - Add EFI Disk
   - Enable Qemu Agent

2. Add GPU via Hardware tab:
   - Add PCI Device
   - Select your GPU
   - Enable "All Functions" if GPU has audio
   - Enable "ROM-Bar"
   - Enable "PCI-Express"

3. For NVIDIA GPUs, you may need:
   - Add "args" line to VM config file (/etc/pve/qemu-server/VMID.conf):
     args: -cpu host,kvm=off,hv_vendor_id=whatever
   
4. Common VM config additions:
   vga: none
   hostpci0: 01:00,pcie=1,x-vga=1
   hostpci1: 01:00.1,pcie=1  # If GPU has audio

EOF
}

bind_gpu_to_vfio() {
    print_header "Manual GPU Binding to VFIO"
    
    if [ $# -eq 0 ]; then
        echo "Usage: $0 bind <PCI_ID>"
        echo "Example: $0 bind 10de:2204"
        return 1
    fi
    
    pci_id="$1"
    
    # Find PCI slot for this ID
    pci_slot=$(lspci -n | grep "$pci_id" | awk '{print $1}')
    
    if [ -z "$pci_slot" ]; then
        print_error "PCI ID $pci_id not found"
        return 1
    fi
    
    echo "Binding PCI device $pci_slot ($pci_id) to vfio-pci..."
    
    # Unbind from current driver if any
    current_driver=$(lspci -k -s "$pci_slot" | grep "Kernel driver in use:" | awk '{print $5}')
    if [ -n "$current_driver" ]; then
        echo "Unbinding from $current_driver..."
        echo "$pci_slot" > "/sys/bus/pci/drivers/$current_driver/unbind" 2>/dev/null || true
    fi
    
    # Bind to vfio-pci
    vendor_device=$(lspci -n -s "$pci_slot" | awk '{print $3}')
    echo "$vendor_device" > /sys/bus/pci/drivers/vfio-pci/new_id
    echo "$pci_slot" > /sys/bus/pci/drivers/vfio-pci/bind
    
    print_success "Successfully bound $pci_slot to vfio-pci"
}

usage() {
    cat << EOF
GPU Passthrough Management Script

Usage: $0 [COMMAND]

Commands:
    check       - Run all checks (default)
    iommu       - Check IOMMU status
    detect      - Detect GPU devices
    vfio        - Check VFIO driver status
    binding     - Check GPU driver binding
    blacklist   - Check blacklisted drivers
    vm-config   - Show VM configuration example
    bind <ID>   - Manually bind GPU to vfio-pci
    help        - Show this help

Examples:
    $0                    # Run all checks
    $0 detect             # Detect GPU devices
    $0 bind 10de:2204     # Bind specific GPU to vfio-pci

EOF
}

main() {
    case "${1:-check}" in
        check)
            check_iommu
            echo ""
            detect_gpu
            echo ""
            check_vfio
            echo ""
            check_gpu_binding
            echo ""
            check_blacklist
            ;;
        iommu)
            check_iommu
            ;;
        detect)
            detect_gpu
            ;;
        vfio)
            check_vfio
            ;;
        binding)
            check_gpu_binding
            ;;
        blacklist)
            check_blacklist
            ;;
        vm-config)
            show_vm_config_example
            ;;
        bind)
            bind_gpu_to_vfio "$2"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
