#!/bin/bash

# Manual GPU Binding Script for Proxmox GPU Passthrough
# This script will unbind the GPU from NVIDIA drivers and bind it to VFIO

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_header "GPU Binding to VFIO"

# Detect NVIDIA GPUs
nvidia_devices=$(lspci -nn | grep -iE "(nvidia|geforce)")

if [ -z "$nvidia_devices" ]; then
    print_warning "No NVIDIA devices found"
    exit 0
fi

echo "Found NVIDIA devices:"
echo "$nvidia_devices"
echo ""

# Process each NVIDIA device
echo "$nvidia_devices" | while read line; do
    pci_slot=$(echo "$line" | awk '{print $1}')
    pci_id=$(echo "$line" | grep -o '\[.*:.*\]' | tail -1 | tr -d '[]')
    device_name=$(echo "$line" | sed 's/^[^ ]* //' | sed 's/ \[.*\].*$//')
    
    echo "Processing: $device_name ($pci_slot, $pci_id)"
    
    # Check current driver
    current_driver=$(lspci -k -s "$pci_slot" | grep "Kernel driver in use:" | awk '{print $5}')
    
    if [ -z "$current_driver" ]; then
        print_warning "No driver currently bound to $pci_slot"
    else
        echo "Current driver: $current_driver"
        
        if [ "$current_driver" = "vfio-pci" ]; then
            print_success "$pci_slot is already bound to vfio-pci"
            continue
        fi
        
        # Unbind from current driver
        echo "Unbinding $pci_slot from $current_driver..."
        if echo "$pci_slot" > "/sys/bus/pci/drivers/$current_driver/unbind" 2>/dev/null; then
            print_success "Successfully unbound from $current_driver"
        else
            print_error "Failed to unbind from $current_driver"
            continue
        fi
        
        sleep 1
    fi
    
    # Bind to vfio-pci
    echo "Binding $pci_slot to vfio-pci..."
    
    # Add the PCI ID to vfio-pci if not already there
    if ! grep -q "$pci_id" /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null; then
        if echo "$pci_id" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null; then
            echo "Added $pci_id to vfio-pci new_id"
        else
            print_warning "Could not add $pci_id to vfio-pci new_id (may already exist)"
        fi
    fi
    
    # Bind the device
    if echo "$pci_slot" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null; then
        print_success "Successfully bound $pci_slot to vfio-pci"
    else
        print_error "Failed to bind $pci_slot to vfio-pci"
    fi
    
    echo ""
done

print_header "Verification"

# Verify the binding
lspci -nn | grep -iE "(nvidia|geforce)" | while read line; do
    pci_slot=$(echo "$line" | awk '{print $1}')
    pci_id=$(echo "$line" | grep -o '\[.*:.*\]' | tail -1 | tr -d '[]')
    driver=$(lspci -k -s "$pci_slot" | grep "Kernel driver in use:" | awk '{print $5}')
    
    if [ "$driver" = "vfio-pci" ]; then
        print_success "GPU $pci_id ($pci_slot) is bound to vfio-pci"
    elif [ -n "$driver" ]; then
        print_error "GPU $pci_id ($pci_slot) is still bound to: $driver"
    else
        print_warning "GPU $pci_id ($pci_slot) has no driver bound"
    fi
done

echo ""
print_header "VFIO Devices"
ls -la /dev/vfio/ 2>/dev/null || print_warning "No VFIO devices found"

echo ""
print_success "GPU binding process completed!"
echo "You can now run: /usr/local/bin/check-gpu-passthrough"
