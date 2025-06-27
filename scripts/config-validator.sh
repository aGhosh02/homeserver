#!/bin/bash
# Configuration Validator for Proxmox Homeserver
# Validates all configuration files and settings

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
ERRORS=0

# Helper functions
print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║$(printf '%*s' -$((31 + ${#1}/2)) "$1")$(printf '%*s' -$((31 - ${#1}/2)) "")║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
    echo -e "\n${BLUE}▶ $1${NC}"
    echo -e "${BLUE}$(printf '─%.0s' {1..50})${NC}"
}

check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((PASSED_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNINGS++))
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((ERRORS++))
}

check_info() {
    echo -e "  ℹ $1"
}

run_check() {
    ((TOTAL_CHECKS++))
    "$@"
}

# Validation functions
validate_project_structure() {
    print_section "Project Structure Validation"
    
    local required_dirs=(
        "$ANSIBLE_DIR"
        "$ANSIBLE_DIR/inventories"
        "$ANSIBLE_DIR/inventories/production"
        "$ANSIBLE_DIR/playbooks"
        "$ANSIBLE_DIR/roles"
        "$PROJECT_ROOT/docs"
        "$PROJECT_ROOT/scripts"
    )
    
    for dir in "${required_dirs[@]}"; do
        run_check validate_directory "$dir"
    done
    
    local required_files=(
        "$PROJECT_ROOT/Makefile"
        "$PROJECT_ROOT/README.md"
        "$PROJECT_ROOT/LICENSE"
        "$ANSIBLE_DIR/ansible.cfg"
        "$ANSIBLE_DIR/requirements.yml"
        "$ANSIBLE_DIR/inventories/production/hosts.yml"
        "$ANSIBLE_DIR/playbooks/site.yml"
    )
    
    for file in "${required_files[@]}"; do
        run_check validate_file "$file"
    done
}

validate_directory() {
    if [[ -d "$1" ]]; then
        check_pass "Directory exists: $1"
    else
        check_fail "Missing directory: $1"
    fi
}

validate_file() {
    if [[ -f "$1" ]]; then
        check_pass "File exists: $1"
    else
        check_fail "Missing file: $1"
    fi
}

validate_ansible_config() {
    print_section "Ansible Configuration Validation"
    
    local ansible_cfg="$ANSIBLE_DIR/ansible.cfg"
    
    if [[ -f "$ansible_cfg" ]]; then
        run_check check_ansible_cfg_setting "$ansible_cfg" "inventory" "inventories/production"
        run_check check_ansible_cfg_setting "$ansible_cfg" "host_key_checking" "False"
        run_check check_ansible_cfg_setting "$ansible_cfg" "retry_files_enabled" "False"
        run_check check_ansible_cfg_setting "$ansible_cfg" "gathering" "smart"
    else
        check_fail "Ansible configuration file not found"
    fi
}

check_ansible_cfg_setting() {
    local config_file="$1"
    local setting="$2"
    local expected="$3"
    
    if grep -q "^$setting.*$expected" "$config_file"; then
        check_pass "Ansible config: $setting = $expected"
    else
        check_warn "Ansible config: $setting may not be properly set"
        check_info "Expected: $setting = $expected"
    fi
}

validate_inventory() {
    print_section "Inventory Validation"
    
    local inventory_file="$ANSIBLE_DIR/inventories/production/hosts.yml"
    
    if [[ -f "$inventory_file" ]]; then
        run_check validate_yaml_syntax "$inventory_file"
        run_check check_inventory_structure "$inventory_file"
        run_check check_host_configuration "$inventory_file"
        run_check check_security_settings "$inventory_file"
    else
        check_fail "Inventory file not found"
    fi
}

validate_yaml_syntax() {
    local file="$1"
    
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            check_pass "YAML syntax valid: $(basename "$file")"
        else
            check_fail "YAML syntax error in: $(basename "$file")"
        fi
    else
        check_warn "Python3 not available for YAML validation"
    fi
}

check_inventory_structure() {
    local inventory_file="$1"
    
    if grep -q "proxmox:" "$inventory_file"; then
        check_pass "Proxmox group defined in inventory"
    else
        check_fail "Proxmox group not found in inventory"
    fi
    
    if grep -q "ansible_host:" "$inventory_file"; then
        check_pass "Host IP address configured"
    else
        check_fail "Host IP address not configured"
    fi
    
    if grep -q "ansible_user:" "$inventory_file"; then
        check_pass "Ansible user configured"
    else
        check_warn "Ansible user not explicitly configured"
    fi
}

check_host_configuration() {
    local inventory_file="$1"
    
    # Check for authentication method
    if grep -q "ansible_ssh_private_key_file:" "$inventory_file" || 
       grep -q "ansible_ssh_pass:" "$inventory_file"; then
        check_pass "Authentication method configured"
    else
        check_fail "No authentication method configured"
    fi
    
    # Check IP address format
    local ip_line=$(grep "ansible_host:" "$inventory_file" | head -1)
    if [[ -n "$ip_line" ]]; then
        local ip_addr=$(echo "$ip_line" | cut -d':' -f2 | tr -d ' ')
        if [[ $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            check_pass "Valid IP address format: $ip_addr"
        else
            check_warn "IP address format may be invalid: $ip_addr"
        fi
    fi
}

check_security_settings() {
    local inventory_file="$1"
    
    # Check for hardcoded passwords (security risk)
    if grep -q "ansible_ssh_pass:.*[^{]" "$inventory_file" && ! grep -q "vault_" "$inventory_file"; then
        check_warn "Hardcoded password detected - consider using vault"
        check_info "Use 'make edit-vault' to encrypt sensitive data"
    else
        check_pass "No hardcoded passwords detected"
    fi
    
    # Check for vault usage
    if grep -q "vault_" "$inventory_file"; then
        check_pass "Ansible vault variables detected"
    else
        check_info "Consider using Ansible vault for sensitive data"
    fi
}

validate_playbooks() {
    print_section "Playbook Validation"
    
    local playbooks=(
        "$ANSIBLE_DIR/playbooks/site.yml"
        "$ANSIBLE_DIR/playbooks/validate.yml"
        "$ANSIBLE_DIR/playbooks/maintenance.yml"
        "$ANSIBLE_DIR/playbooks/deploy-haos.yml"
    )
    
    for playbook in "${playbooks[@]}"; do
        if [[ -f "$playbook" ]]; then
            run_check validate_yaml_syntax "$playbook"
            run_check check_playbook_structure "$playbook"
        else
            check_warn "Playbook not found: $(basename "$playbook")"
        fi
    done
}

check_playbook_structure() {
    local playbook="$1"
    
    if grep -q "hosts:" "$playbook"; then
        check_pass "Hosts defined in: $(basename "$playbook")"
    else
        check_fail "No hosts defined in: $(basename "$playbook")"
    fi
    
    if grep -q "roles:" "$playbook" || grep -q "tasks:" "$playbook"; then
        check_pass "Tasks/roles defined in: $(basename "$playbook")"
    else
        check_warn "No tasks or roles in: $(basename "$playbook")"
    fi
}

validate_roles() {
    print_section "Role Validation"
    
    local roles_dir="$ANSIBLE_DIR/roles"
    
    if [[ -d "$roles_dir" ]]; then
        local roles=($(find "$roles_dir" -maxdepth 1 -type d -not -name "roles" | sed 's|.*/||'))
        
        for role in "${roles[@]}"; do
            run_check validate_role_structure "$roles_dir/$role"
        done
    else
        check_fail "Roles directory not found"
    fi
}

validate_role_structure() {
    local role_dir="$1"
    local role_name=$(basename "$role_dir")
    
    if [[ -d "$role_dir" ]]; then
        check_pass "Role directory exists: $role_name"
        
        # Check for required directories
        local required_dirs=("tasks" "defaults" "handlers" "meta")
        for dir in "${required_dirs[@]}"; do
            if [[ -d "$role_dir/$dir" ]]; then
                check_pass "Role $role_name has $dir directory"
            else
                check_warn "Role $role_name missing $dir directory"
            fi
        done
        
        # Check for main.yml files
        if [[ -f "$role_dir/tasks/main.yml" ]]; then
            check_pass "Role $role_name has tasks/main.yml"
            run_check validate_yaml_syntax "$role_dir/tasks/main.yml"
        else
            check_fail "Role $role_name missing tasks/main.yml"
        fi
        
        if [[ -f "$role_dir/defaults/main.yml" ]]; then
            check_pass "Role $role_name has defaults/main.yml"
            run_check validate_yaml_syntax "$role_dir/defaults/main.yml"
        else
            check_warn "Role $role_name missing defaults/main.yml"
        fi
    else
        check_fail "Role directory not found: $role_name"
    fi
}

validate_dependencies() {
    print_section "Dependencies Validation"
    
    local requirements_file="$ANSIBLE_DIR/requirements.yml"
    
    if [[ -f "$requirements_file" ]]; then
        run_check validate_yaml_syntax "$requirements_file"
        run_check check_requirements_content "$requirements_file"
    else
        check_fail "Requirements file not found"
    fi
    
    # Check if dependencies are installed
    run_check check_ansible_collections
}

check_requirements_content() {
    local requirements_file="$1"
    
    if grep -q "collections:" "$requirements_file"; then
        check_pass "Collections defined in requirements"
    else
        check_warn "No collections defined in requirements"
    fi
    
    # Check for essential collections
    local essential_collections=("ansible.posix" "community.general")
    for collection in "${essential_collections[@]}"; do
        if grep -q "$collection" "$requirements_file"; then
            check_pass "Essential collection found: $collection"
        else
            check_warn "Essential collection missing: $collection"
        fi
    done
}

check_ansible_collections() {
    if command -v ansible-galaxy >/dev/null 2>&1; then
        local installed_collections=$(ansible-galaxy collection list 2>/dev/null | grep -c "^[a-z]" || echo "0")
        if [[ $installed_collections -gt 0 ]]; then
            check_pass "Ansible collections installed ($installed_collections found)"
        else
            check_warn "No Ansible collections found - run 'make install-deps'"
        fi
    else
        check_warn "ansible-galaxy command not found"
    fi
}

validate_scripts() {
    print_section "Scripts Validation"
    
    local scripts_dir="$PROJECT_ROOT/scripts"
    
    if [[ -d "$scripts_dir" ]]; then
        local scripts=($(find "$scripts_dir" -name "*.sh" -type f))
        
        for script in "${scripts[@]}"; do
            run_check check_script_executable "$script"
            run_check check_script_syntax "$script"
        done
    else
        check_warn "Scripts directory not found"
    fi
}

check_script_executable() {
    local script="$1"
    
    if [[ -x "$script" ]]; then
        check_pass "Script is executable: $(basename "$script")"
    else
        check_warn "Script not executable: $(basename "$script")"
        check_info "Run: chmod +x $script"
    fi
}

check_script_syntax() {
    local script="$1"
    
    if bash -n "$script" 2>/dev/null; then
        check_pass "Script syntax valid: $(basename "$script")"
    else
        check_fail "Script syntax error: $(basename "$script")"
    fi
}

validate_makefile() {
    print_section "Makefile Validation"
    
    local makefile="$PROJECT_ROOT/Makefile"
    
    if [[ -f "$makefile" ]]; then
        run_check check_makefile_targets "$makefile"
        run_check check_makefile_help "$makefile"
    else
        check_fail "Makefile not found"
    fi
}

check_makefile_targets() {
    local makefile="$1"
    
    local essential_targets=("help" "setup" "run" "validate" "clean")
    
    for target in "${essential_targets[@]}"; do
        if grep -q "^$target:" "$makefile"; then
            check_pass "Makefile target exists: $target"
        else
            check_warn "Makefile target missing: $target"
        fi
    done
}

check_makefile_help() {
    local makefile="$1"
    
    if grep -q "## " "$makefile"; then
        check_pass "Makefile has help documentation"
    else
        check_warn "Makefile missing help documentation"
    fi
}

validate_documentation() {
    print_section "Documentation Validation"
    
    local docs_dir="$PROJECT_ROOT/docs"
    local essential_docs=("INSTALLATION.md" "ARCHITECTURE.md" "TROUBLESHOOTING.md")
    
    if [[ -d "$docs_dir" ]]; then
        for doc in "${essential_docs[@]}"; do
            if [[ -f "$docs_dir/$doc" ]]; then
                check_pass "Documentation exists: $doc"
            else
                check_warn "Documentation missing: $doc"
            fi
        done
    else
        check_warn "Documentation directory not found"
    fi
    
    # Check README
    if [[ -f "$PROJECT_ROOT/README.md" ]]; then
        check_pass "README.md exists"
        run_check check_readme_content "$PROJECT_ROOT/README.md"
    else
        check_fail "README.md not found"
    fi
}

check_readme_content() {
    local readme="$1"
    
    local essential_sections=("Installation" "Usage" "Configuration")
    
    for section in "${essential_sections[@]}"; do
        if grep -qi "$section" "$readme"; then
            check_pass "README contains $section section"
        else
            check_warn "README missing $section section"
        fi
    done
}

# Network configuration validation
validate_network_config() {
    print_section "Network Configuration Validation"
    
    local inventory_file="$ANSIBLE_DIR/inventories/production/hosts.yml"
    
    if [[ -f "$inventory_file" ]]; then
        run_check check_network_variables "$inventory_file"
        run_check check_ip_ranges "$inventory_file"
    fi
}

check_network_variables() {
    local inventory_file="$1"
    
    if grep -q "network_config:" "$inventory_file"; then
        check_pass "Network configuration defined"
    else
        check_warn "Network configuration not found"
    fi
    
    if grep -q "vm_bridge:" "$inventory_file"; then
        check_pass "VM bridge configuration found"
    else
        check_warn "VM bridge configuration not found"
    fi
}

check_ip_ranges() {
    local inventory_file="$1"
    
    # Check for IP range conflicts
    local management_ip=$(grep "ansible_host:" "$inventory_file" | head -1 | cut -d':' -f2 | tr -d ' ')
    local vm_network=$(grep -A5 "vm_bridge:" "$inventory_file" | grep "network:" | cut -d':' -f2 | tr -d ' ')
    
    if [[ -n "$management_ip" && -n "$vm_network" ]]; then
        check_pass "Network ranges configured"
        check_info "Management IP: $management_ip"
        check_info "VM Network: $vm_network"
    else
        check_warn "Network configuration incomplete"
    fi
}

# GPU configuration validation
validate_gpu_config() {
    print_section "GPU Passthrough Configuration Validation"
    
    local inventory_file="$ANSIBLE_DIR/inventories/production/hosts.yml"
    
    if [[ -f "$inventory_file" ]] && grep -q "gpu_passthrough:" "$inventory_file"; then
        run_check check_gpu_settings "$inventory_file"
        run_check check_iommu_config "$inventory_file"
    else
        check_info "GPU passthrough not configured (optional)"
    fi
}

check_gpu_settings() {
    local inventory_file="$1"
    
    if grep -A10 "gpu_passthrough:" "$inventory_file" | grep -q "enabled: true"; then
        check_pass "GPU passthrough enabled"
        
        if grep -A10 "iommu:" "$inventory_file" | grep -q "kernel_params:"; then
            check_pass "IOMMU kernel parameters configured"
        else
            check_warn "IOMMU kernel parameters not configured"
        fi
    else
        check_info "GPU passthrough disabled"
    fi
}

check_iommu_config() {
    local inventory_file="$1"
    
    local kernel_params=$(grep -A5 "iommu:" "$inventory_file" | grep "kernel_params:" | cut -d'"' -f2)
    
    if [[ -n "$kernel_params" ]]; then
        if [[ "$kernel_params" =~ intel_iommu=on|amd_iommu=on ]]; then
            check_pass "Valid IOMMU kernel parameters: $kernel_params"
        else
            check_warn "IOMMU kernel parameters may be invalid: $kernel_params"
        fi
    fi
}

# Generate validation report
generate_report() {
    print_section "Validation Summary"
    
    echo -e "\n${BLUE}📊 Validation Results:${NC}"
    echo -e "Total Checks: $TOTAL_CHECKS"
    echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
    echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    echo -e "${RED}Errors: $ERRORS${NC}"
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    echo -e "\nSuccess Rate: $success_rate%"
    
    if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 Configuration validation completed successfully!${NC}"
        echo -e "${GREEN}Your configuration is ready for deployment.${NC}"
        return 0
    elif [[ $ERRORS -eq 0 ]]; then
        echo -e "\n${YELLOW}⚠️  Configuration validation completed with warnings.${NC}"
        echo -e "${YELLOW}Consider addressing the warnings before deployment.${NC}"
        return 1
    else
        echo -e "\n${RED}❌ Configuration validation failed with errors.${NC}"
        echo -e "${RED}Please fix the errors before proceeding with deployment.${NC}"
        return 2
    fi
}

# Main execution
main() {
    print_header "🔍 Configuration Validator"
    
    echo -e "${BLUE}Validating Proxmox homeserver configuration...${NC}\n"
    
    # Run all validations
    validate_project_structure
    validate_ansible_config
    validate_inventory
    validate_playbooks
    validate_roles
    validate_dependencies
    validate_scripts
    validate_makefile
    validate_documentation
    validate_network_config
    validate_gpu_config
    
    # Generate and display report
    generate_report
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
