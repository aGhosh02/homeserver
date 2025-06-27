#!/bin/bash

# OpenMediaVault VM Deployment Script
# This script deploys OpenMediaVault VM on Proxmox using Ansible

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")/ansible"
PLAYBOOK="$ANSIBLE_DIR/playbooks/deploy-omv.yml"
INVENTORY="$ANSIBLE_DIR/inventories/production/hosts.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
OpenMediaVault VM Deployment Script

Usage: $0 [OPTIONS]

Options:
    -h, --help              Show this help message
    -i, --inventory FILE    Specify inventory file (default: $INVENTORY)
    -v, --verbose           Enable verbose output
    --check                 Run in check mode (dry-run)
    --tags TAGS             Only run tasks with these tags
    --skip-tags TAGS        Skip tasks with these tags
    --force                 Force creation even if VM exists
    --disks DISKS           Comma-separated list of disks to passthrough (e.g., sdb,sdc)
    --memory SIZE           Memory size in MB (default: 4096)
    --cores NUM             Number of CPU cores (default: 2)
    --hostname NAME         VM hostname (default: openmediavault)

Examples:
    $0                                          # Basic deployment
    $0 --verbose                               # Verbose output
    $0 --disks sdb,sdc                        # With disk passthrough
    $0 --memory 8192 --cores 4                # Custom resources
    $0 --check                                 # Dry-run
    $0 --force                                 # Force creation
    $0 --tags vm-setup                        # Only VM setup tasks

EOF
}

# Parse command line arguments
VERBOSE=""
CHECK_MODE=""
EXTRA_VARS=""
ANSIBLE_TAGS=""
SKIP_TAGS=""
PASSTHROUGH_DISKS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--inventory)
            INVENTORY="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-vvv"
            shift
            ;;
        --check)
            CHECK_MODE="--check"
            shift
            ;;
        --tags)
            ANSIBLE_TAGS="--tags $2"
            shift 2
            ;;
        --skip-tags)
            SKIP_TAGS="--skip-tags $2"
            shift 2
            ;;
        --force)
            EXTRA_VARS="${EXTRA_VARS} omv_skip_if_exists=false"
            shift
            ;;
        --disks)
            PASSTHROUGH_DISKS="$2"
            shift 2
            ;;
        --memory)
            EXTRA_VARS="${EXTRA_VARS} omv_vm.memory=$2"
            shift 2
            ;;
        --cores)
            EXTRA_VARS="${EXTRA_VARS} omv_vm.cpu.cores=$2"
            shift 2
            ;;
        --hostname)
            EXTRA_VARS="${EXTRA_VARS} omv_vm.hostname=$2"
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate requirements
print_status "Validating requirements..."

if ! command -v ansible-playbook &> /dev/null; then
    print_error "ansible-playbook not found. Please install Ansible."
    exit 1
fi

if [[ ! -f "$PLAYBOOK" ]]; then
    print_error "Playbook not found: $PLAYBOOK"
    exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
    print_error "Inventory file not found: $INVENTORY"
    exit 1
fi

# Process passthrough disks
if [[ -n "$PASSTHROUGH_DISKS" ]]; then
    # Convert comma-separated list to JSON array format
    IFS=',' read -ra DISK_ARRAY <<< "$PASSTHROUGH_DISKS"
    DISK_JSON="["
    for i in "${!DISK_ARRAY[@]}"; do
        [[ $i -gt 0 ]] && DISK_JSON+=","
        DISK_JSON+="\"${DISK_ARRAY[i]}\""
    done
    DISK_JSON+="]"
    
    EXTRA_VARS="${EXTRA_VARS} omv_vm.nas_storage.passthrough_disks='${DISK_JSON}'"
    print_status "Configured disk passthrough: ${PASSTHROUGH_DISKS}"
fi

print_success "Requirements validated"

# Display configuration
print_status "Deployment Configuration:"
print_status "  Playbook: $PLAYBOOK"
print_status "  Inventory: $INVENTORY"
[[ -n "$VERBOSE" ]] && print_status "  Verbose: Enabled"
[[ -n "$CHECK_MODE" ]] && print_status "  Check Mode: Enabled"
[[ -n "$ANSIBLE_TAGS" ]] && print_status "  Tags: $ANSIBLE_TAGS"
[[ -n "$SKIP_TAGS" ]] && print_status "  Skip Tags: $SKIP_TAGS"
[[ -n "$EXTRA_VARS" ]] && print_status "  Extra Variables: $EXTRA_VARS"

# Confirmation
if [[ -z "$CHECK_MODE" ]]; then
    echo
    print_warning "This will deploy OpenMediaVault VM on Proxmox."
    read -p "Continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled"
        exit 0
    fi
fi

# Change to ansible directory
cd "$ANSIBLE_DIR"

# Build ansible command
ANSIBLE_CMD="ansible-playbook $PLAYBOOK -i $INVENTORY"
[[ -n "$VERBOSE" ]] && ANSIBLE_CMD="$ANSIBLE_CMD $VERBOSE"
[[ -n "$CHECK_MODE" ]] && ANSIBLE_CMD="$ANSIBLE_CMD $CHECK_MODE"
[[ -n "$ANSIBLE_TAGS" ]] && ANSIBLE_CMD="$ANSIBLE_CMD $ANSIBLE_TAGS"
[[ -n "$SKIP_TAGS" ]] && ANSIBLE_CMD="$ANSIBLE_CMD $SKIP_TAGS"
[[ -n "$EXTRA_VARS" ]] && ANSIBLE_CMD="$ANSIBLE_CMD -e '$EXTRA_VARS'"

# Run deployment
print_status "Starting OpenMediaVault VM deployment..."
echo "Command: $ANSIBLE_CMD"
echo

if eval "$ANSIBLE_CMD"; then
    print_success "OpenMediaVault VM deployment completed successfully!"
    echo
    print_status "Next steps:"
    print_status "1. Access Proxmox Web UI to view the new VM"
    print_status "2. Start the VM and open console"
    print_status "3. Follow OpenMediaVault installation wizard"
    print_status "4. Configure network and storage after installation"
    print_status "5. Access OMV Web UI at http://VM_IP (admin/openmediavault)"
else
    print_error "OpenMediaVault VM deployment failed!"
    print_status "Check the output above for error details"
    exit 1
fi
