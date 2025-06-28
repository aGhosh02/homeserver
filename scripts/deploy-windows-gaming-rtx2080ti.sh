#!/bin/bash

# Windows Gaming VM Deployment Script - RTX 2080 Ti Configuration
# Deploys Windows 11 IoT Enterprise LTSC 2024 with RTX 2080 Ti passthrough

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ANSIBLE_DIR="$PROJECT_ROOT/ansible"

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() { echo -e "${PURPLE}🎮 $1${NC}"; }

print_header "Windows Gaming VM - RTX 2080 Ti Setup"

echo -e "${CYAN}🎯 Target Configuration:${NC}"
echo -e "  💻 OS: Windows 11 IoT Enterprise LTSC 2024"
echo -e "  🧠 CPU: 8 cores (host type, pinned to 0-7)"
echo -e "  💾 RAM: 32GB (dedicated)"
echo -e "  🎮 GPU: RTX 2080 Ti + HDMI Audio (full passthrough)"
echo -e "  ⚡ Features: CPU host type, NUMA, PCIe ACS override, VirtIO drivers"
echo

# Check if PCI IDs are configured
print_info "Checking GPU configuration..."

# Look for RTX 2080 Ti
RTX_DEVICES=$(lspci -nn | grep -i "RTX 2080 Ti" || true)

if [ -z "$RTX_DEVICES" ]; then
    print_warning "RTX 2080 Ti not detected. Please run the PCI ID detection script first:"
    echo -e "  ${GREEN}./scripts/find-gpu-pci-ids.sh${NC}"
    echo
    print_error "Deployment aborted. Configure GPU PCI IDs first."
    exit 1
fi

print_success "RTX 2080 Ti detected!"

# Auto-detect PCI IDs
PRIMARY_GPU_ID=$(echo "$RTX_DEVICES" | grep -v -i audio | head -1 | cut -d' ' -f1)
base_pci=$(echo "$PRIMARY_GPU_ID" | cut -d'.' -f1)
AUDIO_GPU_ID="${base_pci}.1"

# Verify audio device exists
if ! lspci -s "$AUDIO_GPU_ID" &>/dev/null; then
    AUDIO_GPU_ID=$(lspci -nn | grep -i hdmi | grep -i audio | head -1 | cut -d' ' -f1 || true)
fi

if [ -z "$AUDIO_GPU_ID" ]; then
    print_error "Could not detect GPU audio device. Please configure manually."
    exit 1
fi

print_success "Auto-detected configuration:"
echo -e "  🎮 Primary GPU: ${YELLOW}$PRIMARY_GPU_ID${NC}"
echo -e "  🔊 GPU Audio:   ${YELLOW}$AUDIO_GPU_ID${NC}"
echo

# Confirm deployment
echo -e "${CYAN}🚀 Ready to deploy Windows Gaming VM${NC}"
echo -e "${YELLOW}Press Enter to continue or Ctrl+C to abort...${NC}"
read -r

print_header "Starting Deployment"

# Change to ansible directory
cd "$ANSIBLE_DIR"

# Build extra vars with your exact specifications
EXTRA_VARS="windows_vm.memory=32768"
EXTRA_VARS+=" windows_vm.cpu.cores=8"
EXTRA_VARS+=" windows_vm.cpu.type=host"
EXTRA_VARS+=" windows_vm.cpu.numa=true"
EXTRA_VARS+=" windows_vm.cpu.cpu_affinity=0-7"
EXTRA_VARS+=" windows_vm.disk_size=100G"
EXTRA_VARS+=" windows_vm.hostname=windows-gaming"
EXTRA_VARS+=" windows_vm.gpu_passthrough.enabled=true"
EXTRA_VARS+=" windows_vm.gpu_passthrough.primary_gpu=$PRIMARY_GPU_ID"
EXTRA_VARS+=" windows_vm.gpu_passthrough.gpu_audio=$AUDIO_GPU_ID"
EXTRA_VARS+=" windows_vm.pcie.acs_override=true"
EXTRA_VARS+=" performance_tuning.hugepages=true"
EXTRA_VARS+=" performance_tuning.cpu_governor=performance"

print_info "Executing Ansible playbook with RTX 2080 Ti configuration..."

# Run the playbook
if ansible-playbook -i inventories/production playbooks/deploy-windows-gaming.yml -e "$EXTRA_VARS"; then
    print_success "Windows Gaming VM deployment completed successfully!"
    echo
    print_header "🎉 Deployment Complete!"
    echo
    echo -e "${CYAN}📋 VM Configuration:${NC}"
    echo -e "  🆔 Check Proxmox Web UI for VM ID"
    echo -e "  🏷️  Hostname: windows-gaming"
    echo -e "  🧠 CPU: 8 cores (host type, pinned to 0-7)"
    echo -e "  💾 Memory: 32GB dedicated"
    echo -e "  🎮 GPU: RTX 2080 Ti ($PRIMARY_GPU_ID)"
    echo -e "  🔊 Audio: HDMI Audio ($AUDIO_GPU_ID)"
    echo
    echo -e "${CYAN}🚀 Next Steps:${NC}"
    echo -e "  1. 🖥️  Access Proxmox Web Interface"
    echo -e "  2. ▶️  Start the Windows Gaming VM"
    echo -e "  3. 🔌 Connect monitor directly to RTX 2080 Ti"
    echo -e "  4. 💿 Install Windows 11 IoT Enterprise LTSC 2024"
    echo -e "  5. 💾 Install VirtIO drivers from mounted ISO"
    echo -e "  6. 🎮 Install NVIDIA GeForce drivers"
    echo -e "  7. ⚡ Enable Windows Game Mode"
    echo
    echo -e "${CYAN}💡 Pro Tips:${NC}"
    echo -e "  • Use MSI Afterburner for GPU monitoring"
    echo -e "  • Set Windows power plan to High Performance"
    echo -e "  • Enable Windows 11 Game Mode"
    echo -e "  • Configure NVIDIA Control Panel for gaming"
    echo -e "  • Install Steam, Epic Games, or your preferred game launcher"
    echo
    print_success "Happy Gaming with RTX 2080 Ti! 🎮"
else
    print_error "Deployment failed. Check the logs above for details."
    echo
    echo -e "${CYAN}🔧 Troubleshooting Tips:${NC}"
    echo -e "  • Check IOMMU is enabled in BIOS"
    echo -e "  • Verify kernel parameters: intel_iommu=on iommu=pt"
    echo -e "  • Ensure GPU drivers are blacklisted"
    echo -e "  • Check GPU is not in use by host"
    echo -e "  • Run: ${GREEN}./scripts/find-gpu-pci-ids.sh${NC} to verify PCI IDs"
    exit 1
fi
