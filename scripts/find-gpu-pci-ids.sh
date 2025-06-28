#!/bin/bash

# GPU PCI ID Detection Script for Windows Gaming VM
# This script helps find the correct PCI IDs for RTX 2080 Ti

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() { echo -e "${PURPLE}🎮 $1${NC}"; }

print_header "RTX 2080 Ti PCI ID Detection"

echo -e "${CYAN}Scanning for NVIDIA RTX 2080 Ti...${NC}"
echo

# Look for RTX 2080 Ti specifically
RTX_2080_TI_DEVICES=$(lspci -nn | grep -i "RTX 2080 Ti" || true)

if [ -z "$RTX_2080_TI_DEVICES" ]; then
    print_warning "RTX 2080 Ti not found. Showing all NVIDIA devices:"
    echo
    
    # Show all NVIDIA devices
    echo -e "${CYAN}🎯 All NVIDIA Devices:${NC}"
    lspci -nn | grep -i nvidia | while read -r line; do
        pci_id=$(echo "$line" | cut -d' ' -f1)
        device_info=$(echo "$line" | cut -d' ' -f2-)
        echo -e "  📺 ${GREEN}$pci_id${NC}: $device_info"
    done
    echo
else
    print_success "Found RTX 2080 Ti!"
    echo
    
    echo -e "${CYAN}🎯 RTX 2080 Ti Devices:${NC}"
    echo "$RTX_2080_TI_DEVICES" | while read -r line; do
        pci_id=$(echo "$line" | cut -d' ' -f1)
        device_info=$(echo "$line" | cut -d' ' -f2-)
        echo -e "  📺 ${GREEN}$pci_id${NC}: $device_info"
    done
    echo
fi

echo -e "${CYAN}🔊 All Audio Devices (including HDMI Audio):${NC}"
lspci -nn | grep -i audio | while read -r line; do
    pci_id=$(echo "$line" | cut -d' ' -f1)
    device_info=$(echo "$line" | cut -d' ' -f2-)
    echo -e "  🎵 ${GREEN}$pci_id${NC}: $device_info"
done

echo
echo -e "${CYAN}📋 IOMMU Groups (GPU-related):${NC}"
if [ -d "/sys/kernel/iommu_groups" ]; then
    for d in /sys/kernel/iommu_groups/*/devices/*; do
        n=${d#*/iommu_groups/*}; n=${n%%/*}
        device_info=$(lspci -nns "${d##*/}" | grep -i -E "(VGA|Audio|3D|NVIDIA)" || true)
        if [ -n "$device_info" ]; then
            echo -e "  🏷️  Group ${YELLOW}$n${NC}: $device_info"
        fi
    done
else
    print_error "IOMMU not enabled! Enable IOMMU in BIOS and kernel parameters."
fi

echo
print_header "Configuration Instructions"

echo -e "${CYAN}📝 To configure Windows Gaming VM:${NC}"
echo

# Try to identify the most likely RTX 2080 Ti PCI IDs
PRIMARY_GPU_ID=""
AUDIO_GPU_ID=""

if [ -n "$RTX_2080_TI_DEVICES" ]; then
    PRIMARY_GPU_ID=$(echo "$RTX_2080_TI_DEVICES" | grep -v -i audio | head -1 | cut -d' ' -f1)
    
    # Try to find the corresponding audio device
    # Usually audio device is GPU PCI ID with function 1 (e.g., 01:00.0 -> 01:00.1)
    if [ -n "$PRIMARY_GPU_ID" ]; then
        base_pci=$(echo "$PRIMARY_GPU_ID" | cut -d'.' -f1)
        AUDIO_GPU_ID="${base_pci}.1"
        
        # Verify the audio device exists
        if ! lspci -s "$AUDIO_GPU_ID" &>/dev/null; then
            # Try to find HDMI audio device near the GPU
            AUDIO_GPU_ID=$(lspci -nn | grep -i hdmi | grep -i audio | head -1 | cut -d' ' -f1 || true)
        fi
    fi
fi

if [ -n "$PRIMARY_GPU_ID" ] && [ -n "$AUDIO_GPU_ID" ]; then
    echo -e "${GREEN}✅ Auto-detected Configuration:${NC}"
    echo -e "  Primary GPU: ${YELLOW}$PRIMARY_GPU_ID${NC}"
    echo -e "  GPU Audio:   ${YELLOW}$AUDIO_GPU_ID${NC}"
    echo
    
    echo -e "${CYAN}📋 Update these files:${NC}"
    echo
    echo -e "${YELLOW}1. ansible/roles/windows_gaming_vm/defaults/main.yml:${NC}"
    echo -e "   primary_gpu: \"${PRIMARY_GPU_ID}\""
    echo -e "   gpu_audio: \"${AUDIO_GPU_ID}\""
    echo
    echo -e "${YELLOW}2. ansible/playbooks/deploy-windows-gaming.yml:${NC}"
    echo -e "   primary_gpu: \"${PRIMARY_GPU_ID}\""
    echo -e "   gpu_audio: \"${AUDIO_GPU_ID}\""
    echo
    
    echo -e "${CYAN}🚀 Then run deployment:${NC}"
    echo -e "  ${GREEN}./scripts/windows-gaming.sh --gpu $PRIMARY_GPU_ID --audio $AUDIO_GPU_ID${NC}"
    
else
    print_warning "Could not auto-detect RTX 2080 Ti configuration."
    echo -e "${CYAN}👆 Please identify your GPU and audio PCI IDs from the list above${NC}"
    echo
    echo -e "${CYAN}📋 Manual Configuration:${NC}"
    echo -e "  1. Find your RTX 2080 Ti PCI ID (e.g., 01:00.0)"
    echo -e "  2. Find the HDMI audio PCI ID (usually same slot + .1, e.g., 01:00.1)"
    echo -e "  3. Update the configuration files with the correct PCI IDs"
    echo -e "  4. Run: ${GREEN}./scripts/windows-gaming.sh --gpu <GPU_ID> --audio <AUDIO_ID>${NC}"
fi

echo
print_header "Next Steps"

echo -e "${CYAN}🔧 Prerequisites:${NC}"
echo -e "  1. Enable IOMMU in BIOS (Intel VT-d or AMD-Vi)"
echo -e "  2. Add kernel parameters: ${YELLOW}intel_iommu=on iommu=pt${NC} (or amd_iommu=on for AMD)"
echo -e "  3. Blacklist GPU drivers: ${YELLOW}nouveau, nvidia${NC}"
echo -e "  4. Reboot system"
echo

echo -e "${CYAN}📋 Deployment:${NC}"
echo -e "  1. Update PCI IDs in configuration files"
echo -e "  2. Run: ${GREEN}./scripts/windows-gaming.sh${NC}"
echo -e "  3. Start VM and install Windows 11"
echo -e "  4. Install VirtIO drivers and NVIDIA drivers"
echo

print_success "PCI ID detection complete!"
