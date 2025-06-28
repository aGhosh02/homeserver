#!/bin/bash

# Proxmox Storage Debug Script for Windows Gaming VM
# This script helps diagnose storage configuration issues

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
print_header() { echo -e "${PURPLE}💾 $1${NC}"; }

print_header "Proxmox Storage Configuration Debug"

echo -e "${CYAN}🔍 Checking Proxmox storage configuration...${NC}"
echo

# Check if we're on a Proxmox system
if ! command -v pvesm &> /dev/null; then
    print_error "pvesm command not found. This script must be run on a Proxmox VE host."
    exit 1
fi

print_success "Proxmox VE detected"

# Show all storage
print_header "All Configured Storage"
echo -e "${CYAN}📋 Complete storage configuration:${NC}"
pvesm status
echo

# Show storage that supports images
print_header "Storage Supporting VM Images"
IMAGE_STORAGE=$(pvesm status --content images | awk 'NR>1 {print $0}')

if [ -z "$IMAGE_STORAGE" ]; then
    print_error "No storage configured to support VM images!"
    echo
    print_info "To fix this:"
    echo -e "  1. Open Proxmox Web Interface"
    echo -e "  2. Go to Datacenter → Storage"
    echo -e "  3. Select a storage and click 'Edit'"
    echo -e "  4. Ensure 'Disk image' is checked in Content"
    echo -e "  5. Or create new storage with VM image support"
    exit 1
else
    print_success "Found storage that supports VM images:"
    echo "$IMAGE_STORAGE"
fi

echo

# Show active storage only
print_header "Active Storage for VM Images"
ACTIVE_STORAGE=$(pvesm status --content images | awk 'NR>1 && $3=="active" {print $1}')

if [ -z "$ACTIVE_STORAGE" ]; then
    print_error "No active storage found that supports VM images!"
    echo
    print_info "Available storage for images (but not active):"
    pvesm status --content images | awk 'NR>1 && $2!="active" {print "  ❌ " $1 " (" $2 ")"}'
    echo
    print_info "To fix this:"
    echo -e "  1. Check storage connectivity"
    echo -e "  2. Enable/mount the storage"
    echo -e "  3. Verify storage configuration"
    exit 1
else
    print_success "Active storage locations:"
    for storage in $ACTIVE_STORAGE; do
        # Get storage details
        SPACE=$(pvesm status --storage "$storage" | awk 'NR>1 {print $4}')
        TYPE=$(pvesm status --storage "$storage" | awk 'NR>1 {print $3}')
        echo -e "  ✅ ${GREEN}$storage${NC} (${TYPE}, ${SPACE} available)"
    done
fi

echo

# Auto-detect primary storage (what Windows Gaming VM would use)
print_header "Auto-detected Primary Storage"
PRIMARY_STORAGE=$(pvesm status --content images | awk 'NR>1 && $3=="active" {print $1; exit}')

if [ -n "$PRIMARY_STORAGE" ]; then
    print_success "Primary storage for Windows Gaming VM: $PRIMARY_STORAGE"
    
    # Get detailed info about primary storage
    echo -e "${CYAN}📊 Primary storage details:${NC}"
    pvesm status --storage "$PRIMARY_STORAGE" | awk 'NR>1 {
        printf "  • Type: %s\n", $2
        printf "  • Status: %s\n", $3
        printf "  • Total: %s\n", $4
        printf "  • Used: %s\n", $5
        printf "  • Available: %s\n", $6
        printf "  • Usage: %s\n", $7
    }'
    
    # Check if there's enough space for Windows Gaming VM
    AVAILABLE_SPACE=$(pvesm status --storage "$PRIMARY_STORAGE" | awk 'NR>1 {print $6}')
    
    echo
    print_header "Space Requirements Check"
    echo -e "${CYAN}💿 Windows Gaming VM requirements:${NC}"
    echo -e "  • VM Disk: 100GB"
    echo -e "  • EFI Disk: 4GB"
    echo -e "  • Buffer: 10GB"
    echo -e "  • Total Required: 114GB"
    echo
    echo -e "${CYAN}📏 Available space: ${YELLOW}$AVAILABLE_SPACE${NC}"
    
    # Convert space to GB for comparison (simplified)
    if echo "$AVAILABLE_SPACE" | grep -q '^[0-9]\+$'; then
      # Pure number, assume KB
      SPACE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
    elif echo "$AVAILABLE_SPACE" | grep -qi 'T$'; then
      NUMBER=$(echo "$AVAILABLE_SPACE" | sed 's/[^0-9]//g')
      SPACE_GB=$((NUMBER * 1024))
    elif echo "$AVAILABLE_SPACE" | grep -qi 'G$'; then
      SPACE_GB=$(echo "$AVAILABLE_SPACE" | sed 's/[^0-9]//g')
    elif echo "$AVAILABLE_SPACE" | grep -qi 'M$'; then
      NUMBER=$(echo "$AVAILABLE_SPACE" | sed 's/[^0-9]//g')
      SPACE_GB=$((NUMBER / 1024))
    elif echo "$AVAILABLE_SPACE" | grep -qi 'K$'; then
      NUMBER=$(echo "$AVAILABLE_SPACE" | sed 's/[^0-9]//g')
      SPACE_GB=$((NUMBER / 1024))
    else
      SPACE_GB=0
    fi
        
        if [ $SPACE_GB -ge 114 ]; then
            print_success "Sufficient space available (${SPACE_GB}GB >= 114GB)"
        else
            print_warning "Insufficient space (${SPACE_GB}GB < 114GB required)"
            echo -e "${YELLOW}💡 Consider:${NC}"
            echo -e "  • Cleaning up old VMs/containers"
            echo -e "  • Expanding storage"
            echo -e "  • Using different storage location"
        fi
    else
        print_warning "Could not parse available space format: $AVAILABLE_SPACE"
    fi
else
    print_error "No primary storage could be auto-detected!"
fi

echo

# Show storage content types
print_header "Storage Content Types"
echo -e "${CYAN}📂 What each storage supports:${NC}"
pvesm status | awk 'NR>1 {
    cmd = "pvesm status --storage " $1 " 2>/dev/null | awk \"NR>1 {print \\$7}\""
    cmd | getline content
    close(cmd)
    if (content == "") content = "unknown"
    printf "  • %-15s: %s\n", $1, content
}'

echo

# Final recommendations
print_header "Recommendations"

if [ -n "$PRIMARY_STORAGE" ]; then
    print_success "✅ Storage configuration looks good for Windows Gaming VM deployment"
    echo
    print_info "🚀 You can proceed with deployment using:"
    echo -e "  ${GREEN}make deploy-windows-gaming${NC}"
    echo -e "  ${GREEN}make deploy-windows-gaming-auto${NC}"
else
    print_error "❌ Storage configuration needs attention before deploying Windows Gaming VM"
    echo
    print_info "🔧 Steps to fix:"
    echo -e "  1. Configure storage in Proxmox Web UI"
    echo -e "  2. Ensure 'Disk image' content type is enabled"
    echo -e "  3. Verify storage is active and accessible"
    echo -e "  4. Re-run this script to verify"
fi

echo
print_success "Storage configuration check complete!"
