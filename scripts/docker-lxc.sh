#!/bin/bash

# Docker LXC Management Script
# Usage: ./docker-lxc.sh [command] [options]

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="${SCRIPT_DIR}/../ansible"
PLAYBOOK_PATH="${ANSIBLE_DIR}/playbooks/deploy-docker-lxc.yml"
INVENTORY_PATH="${ANSIBLE_DIR}/inventories/production"
LOG_FILE="${SCRIPT_DIR}/../logs/docker-lxc.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Error handling
error_exit() {
    log "${RED}ERROR: $1${NC}"
    exit 1
}

# Success message
success() {
    log "${GREEN}SUCCESS: $1${NC}"
}

# Warning message  
warning() {
    log "${YELLOW}WARNING: $1${NC}"
}

# Info message
info() {
    log "${BLUE}INFO: $1${NC}"
}

# Show usage information
show_usage() {
    cat << EOF
Docker LXC Management Script

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    deploy          Deploy new Docker LXC container
    start           Start Docker LXC container
    stop            Stop Docker LXC container
    restart         Restart Docker LXC container
    status          Show Docker LXC container status
    logs            Show Docker LXC container logs
    enter           Enter Docker LXC container shell
    destroy         Destroy Docker LXC container
    backup          Backup Docker LXC container
    restore         Restore Docker LXC container from backup
    update          Update Docker LXC container
    list-containers List all Docker containers inside LXC
    help            Show this help message

Options:
    --container-id ID    Specify container ID (for operations on existing containers)
    --hostname NAME      Set container hostname (for deployment)
    --memory SIZE        Set memory size in MB (for deployment)  
    --cpu-cores NUM      Set CPU core count (for deployment)
    --disk-size SIZE     Set disk size (for deployment)
    --ip ADDRESS         Set IP address (for deployment)
    --dry-run           Show what would be done without executing
    --verbose           Enable verbose output
    --force             Force operation without confirmation

Examples:
    $0 deploy --hostname docker-services --memory 16384 --cpu-cores 4
    $0 start --container-id 200
    $0 enter --container-id 200
    $0 list-containers --container-id 200
    $0 destroy --container-id 200 --force

EOF
}

# Parse command line arguments
parse_args() {
    COMMAND=""
    CONTAINER_ID=""
    HOSTNAME="docker-services"
    MEMORY="16384"
    CPU_CORES="4"
    DISK_SIZE="100G"
    IP_ADDRESS="dhcp"
    DRY_RUN=false
    VERBOSE=false
    FORCE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            deploy|start|stop|restart|status|logs|enter|destroy|backup|restore|update|list-containers|help)
                COMMAND="$1"
                shift
                ;;
            --container-id)
                CONTAINER_ID="$2"
                shift 2
                ;;
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --memory)
                MEMORY="$2"
                shift 2
                ;;
            --cpu-cores)
                CPU_CORES="$2"
                shift 2
                ;;
            --disk-size)
                DISK_SIZE="$2"
                shift 2
                ;;
            --ip)
                IP_ADDRESS="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
    
    if [[ -z "$COMMAND" ]]; then
        show_usage
        exit 1
    fi
}

# Validate prerequisites
validate_prerequisites() {
    # Check if running on Proxmox
    if ! command -v pveversion >/dev/null 2>&1; then
        error_exit "This script must be run on a Proxmox VE host"
    fi
    
    # Check if Ansible is available
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        error_exit "Ansible is not installed or not in PATH"
    fi
    
    # Check if required files exist
    if [[ ! -f "$PLAYBOOK_PATH" ]]; then
        error_exit "Ansible playbook not found: $PLAYBOOK_PATH"
    fi
    
    if [[ ! -d "$INVENTORY_PATH" ]]; then
        error_exit "Ansible inventory not found: $INVENTORY_PATH"
    fi
}

# Find container ID by hostname
find_container_by_hostname() {
    local hostname="$1"
    local container_id=""
    
    for conf in /etc/pve/lxc/*.conf; do
        if [[ -f "$conf" ]]; then
            if grep -q "hostname: $hostname" "$conf" 2>/dev/null; then
                container_id=$(basename "$conf" .conf)
                echo "$container_id"
                return 0
            fi
        fi
    done
    
    return 1
}

# Deploy new Docker LXC container
deploy_container() {
    info "Starting Docker LXC container deployment..."
    
    local extra_vars="{"
    extra_vars+="\"docker_lxc_override\": {"
    extra_vars+="\"hostname\": \"$HOSTNAME\","
    extra_vars+="\"memory\": $MEMORY,"
    extra_vars+="\"cpu\": {\"cores\": $CPU_CORES},"
    extra_vars+="\"disk_size\": \"$DISK_SIZE\","
    extra_vars+="\"network\": {\"ip\": \"$IP_ADDRESS\"}"
    extra_vars+="}}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: Would deploy container with settings:"
        info "  Hostname: $HOSTNAME"
        info "  Memory: ${MEMORY}MB"
        info "  CPU Cores: $CPU_CORES"
        info "  Disk Size: $DISK_SIZE"
        info "  IP Address: $IP_ADDRESS"
        return 0
    fi
    
    local ansible_cmd="ansible-playbook -i $INVENTORY_PATH $PLAYBOOK_PATH"
    ansible_cmd+=" --extra-vars '$extra_vars'"
    
    if [[ "$VERBOSE" == "true" ]]; then
        ansible_cmd+=" -vvv"
    fi
    
    info "Executing: $ansible_cmd"
    eval "$ansible_cmd" || error_exit "Failed to deploy Docker LXC container"
    
    success "Docker LXC container deployed successfully!"
}

# Start container
start_container() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    info "Starting container $id..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: Would start container $id"
        return 0
    fi
    
    pct start "$id" || error_exit "Failed to start container $id"
    success "Container $id started successfully!"
}

# Stop container
stop_container() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    info "Stopping container $id..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: Would stop container $id"
        return 0
    fi
    
    pct stop "$id" || error_exit "Failed to stop container $id"
    success "Container $id stopped successfully!"
}

# Restart container
restart_container() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    info "Restarting container $id..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: Would restart container $id"
        return 0
    fi
    
    pct restart "$id" || error_exit "Failed to restart container $id"
    success "Container $id restarted successfully!"
}

# Show container status
show_status() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    info "Container $id status:"
    pct status "$id"
    
    info "Container $id configuration:"
    pct config "$id"
    
    # Check Docker status inside container
    if pct status "$id" | grep -q "running"; then
        info "Docker service status inside container:"
        pct exec "$id" -- systemctl status docker --no-pager || true
        
        info "Docker containers running inside LXC:"
        pct exec "$id" -- docker ps || true
    fi
}

# Show container logs
show_logs() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    info "Showing logs for container $id..."
    journalctl -u "pve-container@$id" -f
}

# Enter container shell
enter_container() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    info "Entering container $id shell..."
    pct enter "$id"
}

# List Docker containers inside LXC
list_docker_containers() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    info "Docker containers running in LXC container $id:"
    pct exec "$id" -- docker ps -a
    
    info "Docker images in LXC container $id:"
    pct exec "$id" -- docker images
    
    info "Docker volumes in LXC container $id:"
    pct exec "$id" -- docker volume ls
}

# Destroy container
destroy_container() {
    local id="${CONTAINER_ID:-$(find_container_by_hostname "$HOSTNAME")}"
    
    if [[ -z "$id" ]]; then
        error_exit "Container ID not specified and couldn't find container with hostname: $HOSTNAME"
    fi
    
    if [[ "$FORCE" != "true" ]]; then
        warning "This will permanently delete container $id and all its data!"
        read -p "Are you sure you want to continue? (yes/no): " -r
        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            info "Operation cancelled"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "DRY RUN: Would destroy container $id"
        return 0
    fi
    
    info "Destroying container $id..."
    
    # Stop container if running
    if pct status "$id" | grep -q "running"; then
        pct stop "$id" || warning "Failed to stop container $id"
    fi
    
    # Destroy container
    pct destroy "$id" || error_exit "Failed to destroy container $id"
    
    success "Container $id destroyed successfully!"
}

# Main execution
main() {
    parse_args "$@"
    validate_prerequisites
    
    case "$COMMAND" in
        deploy)
            deploy_container
            ;;
        start)
            start_container
            ;;
        stop)
            stop_container
            ;;
        restart)
            restart_container
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        enter)
            enter_container
            ;;
        list-containers)
            list_docker_containers
            ;;
        destroy)
            destroy_container
            ;;
        help)
            show_usage
            ;;
        *)
            error_exit "Unknown command: $COMMAND"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
