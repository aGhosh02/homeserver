# Architecture Documentation

## Overview

This document describes the architecture and design decisions for the Proxmox homeserver automation project.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Control Machine                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Ansible   │  │  Makefile   │  │   Scripts   │        │
│  │ Playbooks   │  │   Tasks     │  │   Utilities │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────┬───────────────────────────────────┘
                          │ SSH/API
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                 Proxmox VE Host                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Base OS   │  │  Networking │  │ GPU Passth. │        │
│  │ Debian 12   │  │   vmbr0/1   │  │    VFIO     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   VM 100    │  │   VM 101    │  │   VM 102    │        │
│  │ Home Asst.  │  │   Docker    │  │  Windows    │        │
│  │    OS       │  │   Host      │  │    Gaming   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Component Overview

### 1. Ansible Roles

#### proxmox_base
- **Purpose**: Base system configuration and hardening
- **Responsibilities**:
  - Package management and repositories
  - System optimization and tuning
  - Security hardening
  - NTP configuration
  - Logging setup

#### vm_networking
- **Purpose**: Network configuration for VMs
- **Responsibilities**:
  - Bridge interface creation (vmbr1)
  - NAT configuration for internet access
  - Firewall rules setup
  - Network isolation

#### gpu_passthrough
- **Purpose**: GPU passthrough configuration
- **Responsibilities**:
  - IOMMU enablement
  - VFIO driver configuration
  - GPU binding automation
  - Validation scripts

#### haos_vm
- **Purpose**: Home Assistant OS VM deployment
- **Responsibilities**:
  - VM creation and configuration
  - Disk and network setup
  - Resource allocation
  - Boot configuration

### 2. Network Design

```
Internet
    │
    ▼
┌─────────────┐
│   Router    │
│192.168.1.1  │
└─────┬───────┘
      │
      ▼
┌─────────────┐     ┌─────────────┐
│   vmbr0     │────▶│   vmbr1     │
│10.0.200.1   │     │10.0.100.1   │
│(Management) │     │(VM Network) │
└─────────────┘     └─────┬───────┘
                          │
                          ▼
                    ┌─────────────┐
                    │    VMs      │
                    │10.0.100.x   │
                    └─────────────┘
```

## Design Decisions

### 1. Modular Role Structure
- **Decision**: Separate roles for different concerns
- **Rationale**: Better maintainability and reusability
- **Trade-offs**: Slightly more complex structure

### 2. Makefile Task Runner
- **Decision**: Use Makefile for task automation
- **Rationale**: Simple, universal, and well-understood
- **Trade-offs**: Less portable than pure shell scripts

### 3. Ansible Vault for Secrets
- **Decision**: Use Ansible Vault for sensitive data
- **Rationale**: Integrated with Ansible, good security
- **Trade-offs**: Requires password management

### 4. Dedicated VM Network
- **Decision**: Separate network bridge for VMs
- **Rationale**: Better isolation and control
- **Trade-offs**: More complex networking setup

## Security Considerations

### 1. Access Control
- SSH key-based authentication preferred
- Vault encryption for sensitive data
- Firewall rules for network isolation

### 2. Network Security
- Dedicated VM network segment
- NAT for internet access
- Firewall rules for access control

### 3. System Hardening
- Regular security updates
- Minimal package installation
- Service hardening

## Performance Considerations

### 1. Ansible Execution
- Parallel execution with configurable forks
- Fact caching for better performance
- SSH connection multiplexing

### 2. System Optimization
- Kernel tuning for virtualization
- Resource allocation optimization
- I/O scheduling optimization

## Future Improvements

1. **Monitoring Integration**
   - Prometheus metrics collection
   - Grafana dashboard setup
   - Alert manager configuration

2. **Backup Automation**
   - Automated VM backups
   - Configuration backups
   - Disaster recovery procedures

3. **High Availability**
   - Cluster configuration
   - Shared storage setup
   - Failover automation

4. **Container Support**
   - LXC container templates
   - Docker integration
   - Container orchestration
