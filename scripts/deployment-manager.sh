#!/bin/bash
# Deployment Manager Script for Proxmox Homeserver
# Provides guided deployment and management interface

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Logging
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/deployment-manager-$(date +%Y%m%d-%H%M%S).log"

# Helper functions
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║$(printf '%*s' -62 "")║${NC}"
    echo -e "${CYAN}║$(printf '%*s' -$((31 + ${#1}/2)) "$1")$(printf '%*s' -$((31 - ${#1}/2)) "")║${NC}"
    echo -e "${CYAN}║$(printf '%*s' -62 "")║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
    echo -e "${BLUE}$(printf '═%.0s' {1..50})${NC}"
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

print_info() {
    echo -e "${WHITE}ℹ $1${NC}"
}

log() {
    mkdir -p "$LOG_DIR"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Dependency checks
check_dependencies() {
    print_section "Checking Dependencies"
    
    local missing_deps=()
    local deps=("make" "ansible" "ansible-playbook" "git")
    
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            print_success "$dep found"
        else
            print_error "$dep not found"
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo -e "\n${YELLOW}Please install missing dependencies and try again.${NC}"
        exit 1
    fi
    
    # Check Ansible version
    local ansible_version=$(ansible --version | head -n1 | cut -d' ' -f3 | cut -d']' -f1)
    print_info "Ansible version: $ansible_version"
    
    print_success "All dependencies satisfied"
}

# Project setup
setup_project() {
    print_section "Setting Up Project"
    
    cd "$PROJECT_ROOT"
    
    print_info "Installing Ansible dependencies..."
    if make install-deps; then
        print_success "Dependencies installed"
    else
        print_error "Failed to install dependencies"
        return 1
    fi
    
    print_info "Setting up project structure..."
    if make setup; then
        print_success "Project setup complete"
    else
        print_error "Failed to setup project"
        return 1
    fi
}

# Configuration wizard
configuration_wizard() {
    print_section "Configuration Wizard"
    
    local inventory_file="$PROJECT_ROOT/ansible/inventories/production/hosts.yml"
    
    echo -e "${WHITE}Let's configure your Proxmox host settings:${NC}\n"
    
    # Get Proxmox host IP
    read -p "Enter your Proxmox host IP address: " proxmox_ip
    if [[ ! $proxmox_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Invalid IP address format"
        return 1
    fi
    
    # Get authentication method
    echo -e "\nChoose authentication method:"
    echo "1) SSH Key (recommended)"
    echo "2) Password"
    read -p "Enter choice (1-2): " auth_method
    
    case $auth_method in
        1)
            read -p "Enter path to SSH private key [~/.ssh/id_rsa]: " ssh_key
            ssh_key=${ssh_key:-~/.ssh/id_rsa}
            if [[ ! -f "$ssh_key" ]]; then
                print_error "SSH key not found: $ssh_key"
                return 1
            fi
            ;;
        2)
            print_warning "Password authentication selected. Consider using SSH keys for better security."
            read -s -p "Enter SSH password: " ssh_password
            echo
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    # GPU passthrough configuration
    echo -e "\nDo you want to configure GPU passthrough? (y/n)"
    read -p "Choice: " gpu_choice
    
    local gpu_enabled="false"
    local cpu_vendor=""
    if [[ $gpu_choice =~ ^[Yy]$ ]]; then
        gpu_enabled="true"
        echo "Select your CPU vendor:"
        echo "1) Intel"
        echo "2) AMD"
        read -p "Enter choice (1-2): " cpu_choice
        
        case $cpu_choice in
            1) cpu_vendor="intel" ;;
            2) cpu_vendor="amd" ;;
            *) 
                print_error "Invalid choice"
                return 1
                ;;
        esac
    fi
    
    # Home Assistant OS VM
    echo -e "\nDo you want to deploy Home Assistant OS VM? (y/n)"
    read -p "Choice: " haos_choice
    
    local haos_enabled="false"
    if [[ $haos_choice =~ ^[Yy]$ ]]; then
        haos_enabled="true"
    fi
    
    print_info "Updating configuration..."
    
    # Backup existing config
    if [[ -f "$inventory_file" ]]; then
        cp "$inventory_file" "$inventory_file.backup.$(date +%Y%m%d-%H%M%S)"
        print_info "Existing configuration backed up"
    fi
    
    # Generate new configuration
    cat > "$inventory_file" << EOF
---
all:
  children:
    proxmox:
      hosts:
        pve:
          ansible_host: $proxmox_ip
          ansible_user: root
EOF

    if [[ $auth_method == "1" ]]; then
        echo "          ansible_ssh_private_key_file: $ssh_key" >> "$inventory_file"
    else
        echo "          ansible_ssh_pass: \"{{ vault_ssh_password }}\"" >> "$inventory_file"
    fi

    cat >> "$inventory_file" << EOF
    haos:
      hosts:
        pve:
          haos_enabled: $haos_enabled
  vars:
    domain_name: pve.local
    
    # Security Configuration
    security_hardening:
      enabled: true
      
    # GPU Passthrough Configuration
    gpu_passthrough:
      enabled: $gpu_enabled
EOF

    if [[ $gpu_enabled == "true" ]]; then
        if [[ $cpu_vendor == "intel" ]]; then
            echo "      iommu:" >> "$inventory_file"
            echo "        kernel_params: \"intel_iommu=on iommu=pt\"" >> "$inventory_file"
        else
            echo "      iommu:" >> "$inventory_file"
            echo "        kernel_params: \"amd_iommu=on iommu=pt\"" >> "$inventory_file"
        fi
    fi
    
    # Create vault if password authentication is used
    if [[ $auth_method == "2" ]]; then
        print_info "Setting up Ansible vault for password storage..."
        local vault_file="$PROJECT_ROOT/ansible/inventories/production/group_vars/all/vault.yml"
        mkdir -p "$(dirname "$vault_file")"
        
        echo "vault_ssh_password: \"$ssh_password\"" > "$vault_file.tmp"
        
        cd "$PROJECT_ROOT"
        if echo "vault-password" | ansible-vault encrypt "$vault_file.tmp" --output "$vault_file" --vault-password-file /dev/stdin; then
            rm "$vault_file.tmp"
            print_success "Vault created successfully"
            print_warning "Remember the vault password: vault-password"
        else
            print_error "Failed to create vault"
            rm -f "$vault_file.tmp"
            return 1
        fi
    fi
    
    print_success "Configuration completed successfully"
}

# Pre-deployment checks
pre_deployment_checks() {
    print_section "Pre-deployment Checks"
    
    cd "$PROJECT_ROOT"
    
    print_info "Testing connectivity..."
    if make ping; then
        print_success "Connectivity test passed"
    else
        print_error "Connectivity test failed"
        print_info "Please check your network configuration and SSH access"
        return 1
    fi
    
    print_info "Running syntax check..."
    if make syntax-check; then
        print_success "Syntax check passed"
    else
        print_error "Syntax check failed"
        return 1
    fi
    
    print_info "Running security check..."
    if make security-check; then
        print_success "Security check passed"
    else
        print_warning "Security check found issues (non-fatal)"
    fi
    
    print_success "All pre-deployment checks completed"
}

# Main deployment
run_deployment() {
    print_section "Running Deployment"
    
    cd "$PROJECT_ROOT"
    
    echo -e "${WHITE}Deployment options:${NC}"
    echo "1) Full deployment (recommended)"
    echo "2) Base system only"
    echo "3) Network configuration only"
    echo "4) GPU passthrough only"
    echo "5) Home Assistant OS only"
    echo "6) OpenMediaVault NAS only"
    echo "7) Dry run (simulate changes)"
    
    read -p "Enter choice (1-7): " deploy_choice
    
    case $deploy_choice in
        1)
            print_info "Running full deployment..."
            make run
            ;;
        2)
            print_info "Running base system deployment..."
            make run-base
            ;;
        3)
            print_info "Running network configuration..."
            make run-network
            ;;
        4)
            print_info "Running GPU passthrough configuration..."
            make run-gpu
            ;;
        5)
            print_info "Deploying Home Assistant OS..."
            make deploy-haos
            ;;
        6)
            print_info "Deploying OpenMediaVault NAS..."
            make deploy-omv
            ;;
        7)
            print_info "Running deployment simulation..."
            make dry-run
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        print_success "Deployment completed successfully"
    else
        print_error "Deployment failed"
        print_info "Check logs for details: $LOG_FILE"
        return 1
    fi
}

# Post-deployment validation
post_deployment_validation() {
    print_section "Post-deployment Validation"
    
    cd "$PROJECT_ROOT"
    
    print_info "Running system validation..."
    if make validate; then
        print_success "System validation passed"
    else
        print_warning "System validation found issues"
    fi
    
    print_info "Running health check..."
    if ./scripts/health-check.sh; then
        print_success "Health check passed"
    else
        print_warning "Health check found issues"
    fi
    
    # Check GPU passthrough if enabled
    local inventory_file="$PROJECT_ROOT/ansible/inventories/production/hosts.yml"
    if grep -q "gpu_passthrough:" "$inventory_file" && grep -A5 "gpu_passthrough:" "$inventory_file" | grep -q "enabled: true"; then
        print_info "Validating GPU passthrough..."
        if ./scripts/gpu-passthrough-manager.sh check; then
            print_success "GPU passthrough validation passed"
        else
            print_warning "GPU passthrough validation found issues"
        fi
    fi
    
    print_success "Post-deployment validation completed"
}

# Main menu
show_main_menu() {
    clear
    print_header "🏠 Proxmox Homeserver Deployment Manager"
    
    echo -e "${WHITE}Choose an action:${NC}\n"
    echo "1) 🚀 Full Setup (Recommended for new installations)"
    echo "2) ⚙️  Configure Only"
    echo "3) 🔧 Deploy Only"
    echo "4) ✅ Validate Only"
    echo "5) 🏥 Health Check"
    echo "6) 📊 Show Status"
    echo "7) 📋 Show Logs"
    echo "8) 🧹 Cleanup"
    echo "9) ❓ Help"
    echo "0) 🚪 Exit"
    
    echo -e "\n${CYAN}──────────────────────────────────────────${NC}"
    read -p "Enter your choice (0-9): " choice
    
    case $choice in
        1) full_setup ;;
        2) configuration_wizard ;;
        3) deploy_only ;;
        4) validate_only ;;
        5) health_check ;;
        6) show_status ;;
        7) show_logs ;;
        8) cleanup ;;
        9) show_help ;;
        0) exit 0 ;;
        *) 
            print_error "Invalid choice. Please try again."
            sleep 2
            show_main_menu
            ;;
    esac
}

# Full setup workflow
full_setup() {
    log "Starting full setup workflow"
    
    check_dependencies || return 1
    setup_project || return 1
    configuration_wizard || return 1
    pre_deployment_checks || return 1
    run_deployment || return 1
    post_deployment_validation || return 1
    
    print_header "🎉 Setup Complete!"
    
    echo -e "${GREEN}Your Proxmox homeserver has been successfully configured!${NC}\n"
    echo -e "${WHITE}Next steps:${NC}"
    echo "• Access Proxmox web interface: https://$(grep ansible_host "$PROJECT_ROOT/ansible/inventories/production/hosts.yml" | cut -d':' -f2 | tr -d ' '):8006"
    echo "• Check system status: ./scripts/health-check.sh"
    echo "• Review logs: tail -f $LOG_FILE"
    
    log "Full setup workflow completed successfully"
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Deploy only
deploy_only() {
    check_dependencies || return 1
    pre_deployment_checks || return 1
    run_deployment || return 1
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Validate only
validate_only() {
    cd "$PROJECT_ROOT"
    make test
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Health check
health_check() {
    cd "$PROJECT_ROOT"
    ./scripts/health-check.sh
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Show status
show_status() {
    print_section "System Status"
    
    cd "$PROJECT_ROOT"
    make info
    
    if [[ -f "$PROJECT_ROOT/ansible/inventories/production/hosts.yml" ]]; then
        print_info "Configuration file exists"
        local proxmox_ip=$(grep ansible_host "$PROJECT_ROOT/ansible/inventories/production/hosts.yml" | cut -d':' -f2 | tr -d ' ')
        print_info "Proxmox host: $proxmox_ip"
    else
        print_warning "Configuration file not found"
    fi
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Show logs
show_logs() {
    print_section "Recent Logs"
    
    if [[ -d "$LOG_DIR" ]]; then
        echo -e "${WHITE}Available log files:${NC}"
        ls -la "$LOG_DIR" | tail -10
        
        echo -e "\n${WHITE}Recent entries:${NC}"
        tail -20 "$LOG_DIR"/* 2>/dev/null | head -50
    else
        print_info "No logs found"
    fi
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Cleanup
cleanup() {
    print_section "Cleanup"
    
    cd "$PROJECT_ROOT"
    make clean
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Show help
show_help() {
    print_section "Help & Documentation"
    
    echo -e "${WHITE}Available Documentation:${NC}"
    echo "• Installation Guide: docs/INSTALLATION.md"
    echo "• Architecture Overview: docs/ARCHITECTURE.md"
    echo "• Troubleshooting Guide: docs/TROUBLESHOOTING.md"
    echo ""
    echo -e "${WHITE}Useful Commands:${NC}"
    echo "• make help              - Show all available make targets"
    echo "• make validate          - Test system configuration"
    echo "• make dry-run           - Simulate deployment"
    echo "• make backup            - Create configuration backup"
    echo ""
    echo -e "${WHITE}Support:${NC}"
    echo "• GitHub Issues: https://github.com/your-repo/homeserver/issues"
    echo "• Documentation: https://github.com/your-repo/homeserver/tree/main/docs"
    
    read -p "Press Enter to return to main menu..."
    show_main_menu
}

# Main execution
main() {
    # Ensure we're running from the correct directory
    cd "$PROJECT_ROOT"
    
    # Create logs directory
    mkdir -p "$LOG_DIR"
    
    # Start logging
    log "Deployment manager started"
    
    # Show main menu
    show_main_menu
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
