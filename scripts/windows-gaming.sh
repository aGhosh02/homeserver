#!/bin/bash

# Windows Gaming VM Deployment Script for Proxmox VE
# This script provides an easy interface to deploy Windows Gaming VMs

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly ANSIBLE_DIR="$PROJECT_ROOT/ansible"
readonly PLAYBOOK="$ANSIBLE_DIR/playbooks/deploy-windows-gaming.yml"
readonly INVENTORY="$ANSIBLE_DIR/inventories/production"

# Default values
DEFAULT_MEMORY=32768
DEFAULT_CORES=8
DEFAULT_DISK_SIZE="100G"
DEFAULT_HOSTNAME="windows-gaming"
DEFAULT_GPU_PASSTHROUGH=false

# Function to print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() { echo -e "${PURPLE}🎮 $1${NC}"; }

# Function to show usage
show_usage() {
    cat << EOF
🎮 Windows Gaming VM Deployment Script

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -m, --memory MB         Memory allocation in MB (default: $DEFAULT_MEMORY)
    -c, --cores NUM         Number of CPU cores (default: $DEFAULT_CORES)
    -d, --disk SIZE         Disk size (default: $DEFAULT_DISK_SIZE)
    -n, --hostname NAME     VM hostname (default: $DEFAULT_HOSTNAME)
    -g, --gpu PCI_ID        Enable GPU passthrough with primary GPU PCI ID
    -a, --audio PCI_ID      GPU audio PCI ID (required with --gpu)
    -f, --force             Force deployment (overwrite existing VM)
    --dry-run               Show what would be done without executing
    --check                 Check prerequisites only
    --list-gpus             List available GPUs for passthrough
    --performance           Enable performance tuning (hugepages, CPU isolation)
    --no-performance        Disable performance tuning

EXAMPLES:
    # Basic deployment
    $0

    # Custom resources
    $0 --memory 16384 --cores 6 --disk 120G

    # With GPU passthrough
    $0 --gpu 01:00.0 --audio 01:00.1

    # High-performance gaming setup
    $0 --memory 32768 --cores 8 --gpu 01:00.0 --audio 01:00.1 --performance

    # Check prerequisites
    $0 --check

    # List available GPUs
    $0 --list-gpus

NOTES:
    - GPU passthrough requires IOMMU support and proper kernel configuration
    - Use 'lspci | grep VGA' to find GPU PCI IDs
    - Audio PCI ID is usually GPU PCI ID + 1 (e.g., 01:00.0 → 01:00.1)
    - Performance tuning may require system reboot
    - Windows 11 ISO and VirtIO drivers will be downloaded automatically

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local prereq_failed=false
    
    # Check if running on Proxmox
    if ! command -v qm &> /dev/null; then
        print_error "This script must be run on a Proxmox VE host"
        prereq_failed=true
    else
        print_success "Proxmox VE detected"
    fi
    
    # Check Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed"
        prereq_failed=true
    else
        print_success "Ansible found: $(ansible --version | head -1)"
    fi
    
    # Check available memory
    local available_memory
    available_memory=$(free -m | awk '/^Mem:/ {print $7}')
    if [ "$available_memory" -lt 8192 ]; then
        print_warning "Low available memory: ${available_memory}MB (recommended: 8GB+)"
    else
        print_success "Available memory: ${available_memory}MB"
    fi
    
    # Check available CPU cores
    local cpu_cores
    cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt 8 ]; then
        print_warning "Low CPU cores: $cpu_cores (recommended: 8+)"
    else
        print_success "CPU cores: $cpu_cores"
    fi
    
    # Check virtualization support
    if grep -qE "(vmx|svm)" /proc/cpuinfo; then
        print_success "Hardware virtualization supported"
    else
        print_error "Hardware virtualization not supported or not enabled"
        prereq_failed=true
    fi
    
    # Check KVM
    if [ -c /dev/kvm ]; then
        print_success "KVM device available"
    else
        print_error "KVM device not found"
        prereq_failed=true
    fi
    
    # Check IOMMU (for GPU passthrough)
    if [ -d /sys/kernel/iommu_groups ]; then
        print_success "IOMMU enabled"
    else
        print_warning "IOMMU not enabled (required for GPU passthrough)"
    fi
    
    if [ "$prereq_failed" = true ]; then
        print_error "Prerequisites check failed"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to list available GPUs
list_gpus() {
    print_header "Available GPUs for Passthrough"
    
    if ! lspci | grep -i vga &> /dev/null; then
        print_warning "No VGA devices found"
        return
    fi
    
    echo
    echo "🎮 VGA Devices:"
    lspci | grep -i vga | while read -r line; do
        local pci_id
        pci_id=$(echo "$line" | cut -d' ' -f1)
        echo "  📺 $pci_id: $(echo "$line" | cut -d' ' -f2-)"
    done
    
    echo
    echo "🔊 Audio Devices:"
    lspci | grep -i audio | while read -r line; do
        local pci_id
        pci_id=$(echo "$line" | cut -d' ' -f1)
        echo "  🎵 $pci_id: $(echo "$line" | cut -d' ' -f2-)"
    done
    
    echo
    echo "💡 Tips:"
    echo "  - Use the PCI ID (e.g., 01:00.0) for GPU passthrough"
    echo "  - Audio device is usually GPU PCI ID + 1"
    echo "  - Check IOMMU groups: find /sys/kernel/iommu_groups/ -type l"
}

# Function to validate GPU PCI ID format
validate_pci_id() {
    local pci_id="$1"
    if [[ ! "$pci_id" =~ ^[0-9a-fA-F]{2}:[0-9a-fA-F]{2}\.[0-9a-fA-F]$ ]]; then
        print_error "Invalid PCI ID format: $pci_id (expected: XX:XX.X)"
        return 1
    fi
    
    if ! lspci -s "$pci_id" &> /dev/null; then
        print_error "PCI device not found: $pci_id"
        return 1
    fi
    
    return 0
}

# Function to build Ansible extra vars
build_extra_vars() {
    local extra_vars=""
    
    # Basic VM configuration
    extra_vars+="windows_vm.memory=$MEMORY "
    extra_vars+="windows_vm.cpu.cores=$CORES "
    extra_vars+="windows_vm.disk_size=$DISK_SIZE "
    extra_vars+="windows_vm.hostname=$HOSTNAME "
    
    # GPU passthrough configuration
    if [ "$GPU_PASSTHROUGH" = true ]; then
        extra_vars+="windows_vm.gpu_passthrough.enabled=true "
        extra_vars+="windows_vm.gpu_passthrough.primary_gpu=$GPU_PCI_ID "
        extra_vars+="windows_vm.gpu_passthrough.gpu_audio=$GPU_AUDIO_PCI_ID "
    fi
    
    # Performance tuning
    if [ "$PERFORMANCE_TUNING" = true ]; then
        extra_vars+="performance_tuning.hugepages=true "
        extra_vars+="performance_tuning.cpu_governor=performance "
    fi
    
    # Force deployment
    if [ "$FORCE_DEPLOYMENT" = true ]; then
        extra_vars+="windows_skip_if_exists=false "
    fi
    
    echo "$extra_vars"
}

# Function to run deployment
run_deployment() {
    print_header "Starting Windows Gaming VM Deployment"
    
    # Build extra vars
    local extra_vars
    extra_vars=$(build_extra_vars)
    
    print_info "Configuration:"
    echo "  🧠 CPU: $CORES cores"
    echo "  💾 Memory: $((MEMORY / 1024))GB"
    echo "  💿 Disk: $DISK_SIZE"
    echo "  🏷️ Hostname: $HOSTNAME"
    echo "  🎮 GPU Passthrough: $([ "$GPU_PASSTHROUGH" = true ] && echo "Enabled ($GPU_PCI_ID)" || echo "Disabled")"
    echo "  ⚡ Performance Tuning: $([ "$PERFORMANCE_TUNING" = true ] && echo "Enabled" || echo "Disabled")"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "DRY RUN - Would execute:"
        echo "ansible-playbook -i $INVENTORY $PLAYBOOK -e \"$extra_vars\""
        return
    fi
    
    print_info "Executing Ansible playbook..."
    
    # Change to ansible directory
    cd "$ANSIBLE_DIR"
    
    # Run the playbook
    if ansible-playbook -i "$INVENTORY" "$PLAYBOOK" -e "$extra_vars"; then
        print_success "Windows Gaming VM deployment completed successfully!"
        echo
        print_info "Next steps:"
        echo "  1. Access Proxmox web interface"
        echo "  2. Start the VM"
        echo "  3. Connect monitor to GPU (if passthrough enabled)"
        echo "  4. Follow Windows installation process"
    else
        print_error "Deployment failed. Check the logs above for details."
        exit 1
    fi
}

# Main function
main() {
    # Default values
    MEMORY=$DEFAULT_MEMORY
    CORES=$DEFAULT_CORES
    DISK_SIZE=$DEFAULT_DISK_SIZE
    HOSTNAME=$DEFAULT_HOSTNAME
    GPU_PASSTHROUGH=false
    GPU_PCI_ID=""
    GPU_AUDIO_PCI_ID=""
    PERFORMANCE_TUNING=true
    FORCE_DEPLOYMENT=false
    DRY_RUN=false
    CHECK_ONLY=false
    LIST_GPUS_ONLY=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -m|--memory)
                MEMORY="$2"
                shift 2
                ;;
            -c|--cores)
                CORES="$2"
                shift 2
                ;;
            -d|--disk)
                DISK_SIZE="$2"
                shift 2
                ;;
            -n|--hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            -g|--gpu)
                GPU_PCI_ID="$2"
                GPU_PASSTHROUGH=true
                shift 2
                ;;
            -a|--audio)
                GPU_AUDIO_PCI_ID="$2"
                shift 2
                ;;
            -f|--force)
                FORCE_DEPLOYMENT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --check)
                CHECK_ONLY=true
                shift
                ;;
            --list-gpus)
                LIST_GPUS_ONLY=true
                shift
                ;;
            --performance)
                PERFORMANCE_TUNING=true
                shift
                ;;
            --no-performance)
                PERFORMANCE_TUNING=false
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Handle special modes
    if [ "$LIST_GPUS_ONLY" = true ]; then
        list_gpus
        exit 0
    fi
    
    if [ "$CHECK_ONLY" = true ]; then
        check_prerequisites
        exit 0
    fi
    
    # Validate GPU passthrough configuration
    if [ "$GPU_PASSTHROUGH" = true ]; then
        if [ -z "$GPU_PCI_ID" ]; then
            print_error "GPU PCI ID is required for GPU passthrough"
            exit 1
        fi
        
        if [ -z "$GPU_AUDIO_PCI_ID" ]; then
            print_error "GPU audio PCI ID is required for GPU passthrough"
            exit 1
        fi
        
        if ! validate_pci_id "$GPU_PCI_ID"; then
            exit 1
        fi
        
        if ! validate_pci_id "$GPU_AUDIO_PCI_ID"; then
            exit 1
        fi
    fi
    
    # Validate numeric parameters
    if ! [[ "$MEMORY" =~ ^[0-9]+$ ]] || [ "$MEMORY" -lt 2048 ]; then
        print_error "Invalid memory size: $MEMORY (minimum: 2048MB)"
        exit 1
    fi
    
    if ! [[ "$CORES" =~ ^[0-9]+$ ]] || [ "$CORES" -lt 1 ]; then
        print_error "Invalid core count: $CORES (minimum: 1)"
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Run deployment
    run_deployment
}

# Execute main function
main "$@"
