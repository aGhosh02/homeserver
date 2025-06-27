#!/bin/bash
# Proxmox Health Check and Monitoring Script
# This script provides comprehensive system health monitoring

set -euo pipefail

# Configuration
LOG_FILE="/var/log/proxmox-health-check.log"
WARN_THRESHOLD_CPU=80
WARN_THRESHOLD_MEM=80
WARN_THRESHOLD_DISK=85
CRIT_THRESHOLD_CPU=90
CRIT_THRESHOLD_MEM=90
CRIT_THRESHOLD_DISK=95

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check system services
check_services() {
    echo -e "${BLUE}🔍 Checking Proxmox services...${NC}"
    
    local services=("pveproxy" "pvedaemon" "pvestatd" "chronyd" "postfix")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}✅ $service: Running${NC}"
        else
            echo -e "${RED}❌ $service: Failed${NC}"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log "WARNING: Failed services: ${failed_services[*]}"
        return 1
    fi
    
    return 0
}

# Check system resources
check_resources() {
    echo -e "${BLUE}🖥️  Checking system resources...${NC}"
    
    # CPU Usage
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    cpu_usage=${cpu_usage%.*}  # Remove decimal part
    
    if [ "$cpu_usage" -gt "$CRIT_THRESHOLD_CPU" ]; then
        echo -e "${RED}🚨 CPU Usage: ${cpu_usage}% (Critical)${NC}"
        log "CRITICAL: CPU usage is ${cpu_usage}%"
    elif [ "$cpu_usage" -gt "$WARN_THRESHOLD_CPU" ]; then
        echo -e "${YELLOW}⚠️  CPU Usage: ${cpu_usage}% (Warning)${NC}"
        log "WARNING: CPU usage is ${cpu_usage}%"
    else
        echo -e "${GREEN}✅ CPU Usage: ${cpu_usage}%${NC}"
    fi
    
    # Memory Usage
    local mem_info
    mem_info=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    
    if [ "$mem_info" -gt "$CRIT_THRESHOLD_MEM" ]; then
        echo -e "${RED}🚨 Memory Usage: ${mem_info}% (Critical)${NC}"
        log "CRITICAL: Memory usage is ${mem_info}%"
    elif [ "$mem_info" -gt "$WARN_THRESHOLD_MEM" ]; then
        echo -e "${YELLOW}⚠️  Memory Usage: ${mem_info}% (Warning)${NC}"
        log "WARNING: Memory usage is ${mem_info}%"
    else
        echo -e "${GREEN}✅ Memory Usage: ${mem_info}%${NC}"
    fi
    
    # Disk Usage
    local disk_usage
    disk_usage=$(df / | awk 'NR==2{gsub(/%/,"",$5); print $5}')
    
    if [ "$disk_usage" -gt "$CRIT_THRESHOLD_DISK" ]; then
        echo -e "${RED}🚨 Disk Usage: ${disk_usage}% (Critical)${NC}"
        log "CRITICAL: Disk usage is ${disk_usage}%"
    elif [ "$disk_usage" -gt "$WARN_THRESHOLD_DISK" ]; then
        echo -e "${YELLOW}⚠️  Disk Usage: ${disk_usage}% (Warning)${NC}"
        log "WARNING: Disk usage is ${disk_usage}%"
    else
        echo -e "${GREEN}✅ Disk Usage: ${disk_usage}%${NC}"
    fi
}

# Check storage pools
check_storage() {
    echo -e "${BLUE}💾 Checking storage pools...${NC}"
    
    if [ -x "/usr/sbin/pvesm" ] || [ -x "/usr/bin/pvesm" ]; then
        pvesm status | while read -r line; do
            if [[ "$line" =~ ^(local|local-lvm) ]]; then
                echo -e "${GREEN}✅ Storage: $line${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠️  PVE storage commands not available${NC}"
    fi
}

# Check network connectivity
check_network() {
    echo -e "${BLUE}🌐 Checking network connectivity...${NC}"
    
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &> /dev/null; then
            echo -e "${GREEN}✅ Network: $host reachable${NC}"
        else
            echo -e "${RED}❌ Network: $host unreachable${NC}"
            log "WARNING: Cannot reach $host"
        fi
    done
}

# Check certificate validity
check_certificates() {
    echo -e "${BLUE}🔐 Checking SSL certificates...${NC}"
    
    local cert_file="/etc/pve/pve-root-ca.pem"
    if [ -f "$cert_file" ]; then
        local expiry_date
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_timestamp
        expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp
        current_timestamp=$(date +%s)
        local days_until_expiry
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ "$days_until_expiry" -lt 30 ]; then
            echo -e "${RED}🚨 Certificate expires in ${days_until_expiry} days${NC}"
            log "WARNING: Certificate expires in ${days_until_expiry} days"
        elif [ "$days_until_expiry" -lt 90 ]; then
            echo -e "${YELLOW}⚠️  Certificate expires in ${days_until_expiry} days${NC}"
        else
            echo -e "${GREEN}✅ Certificate valid for ${days_until_expiry} days${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Certificate file not found${NC}"
    fi
}

# Generate summary report
generate_report() {
    local report_file="/tmp/proxmox-health-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Proxmox Health Check Report"
        echo "=========================="
        echo "Date: $(date)"
        echo "Hostname: $(hostname -f)"
        echo "Uptime: $(uptime -p)"
        echo ""
        echo "System Information:"
        echo "- OS: $(lsb_release -d | cut -f2)"
        echo "- Kernel: $(uname -r)"
        echo "- CPU: $(lscpu | grep 'Model name' | awk -F: '{print $2}' | xargs)"
        echo "- Memory: $(free -h | awk 'NR==2{print $2}')"
        echo ""
        echo "Resource Usage:"
        echo "- CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')%"
        echo "- Memory: $(free | awk 'NR==2{printf "%.1f", $3*100/$2}')%"
        echo "- Disk: $(df / | awk 'NR==2{print $5}')"
        echo ""
        echo "VM Information:"
        if [ -x "/usr/sbin/qm" ] || [ -x "/usr/bin/qm" ]; then
            qm list
        else
            echo "PVE commands not available"
        fi
    } > "$report_file"
    
    echo -e "${GREEN}📊 Health report generated: $report_file${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🏥 Proxmox Health Check Started${NC}"
    echo "================================="
    
    log "Health check started"
    
    local overall_status=0
    
    check_services || overall_status=1
    echo ""
    
    check_resources || overall_status=1
    echo ""
    
    check_storage || overall_status=1
    echo ""
    
    check_network || overall_status=1
    echo ""
    
    check_certificates || overall_status=1
    echo ""
    
    generate_report
    
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}✅ Overall system health: GOOD${NC}"
        log "Health check completed successfully"
    else
        echo -e "${YELLOW}⚠️  Overall system health: WARNINGS DETECTED${NC}"
        log "Health check completed with warnings"
    fi
    
    echo -e "${BLUE}🏥 Health Check Complete${NC}"
    echo "Check log file: $LOG_FILE"
}

# Run main function
main "$@"
