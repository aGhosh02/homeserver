# Windows Gaming VM Makefile Targets

## Deployment Targets

### `make deploy-windows-gaming`
- **Description**: Deploy Windows Gaming VM with RTX 2080 Ti (8 cores, 32GB RAM, GPU passthrough)
- **Usage**: `make deploy-windows-gaming`
- **What it does**: Runs the Ansible playbook to deploy a Windows Gaming VM with your specifications

### `make deploy-windows-gaming-check`
- **Description**: Check Windows Gaming VM deployment (dry-run)
- **Usage**: `make deploy-windows-gaming-check`
- **What it does**: Performs a dry-run deployment to validate configuration without making changes

### `make deploy-windows-gaming-force`
- **Description**: Force deploy Windows Gaming VM (even if exists)
- **Usage**: `make deploy-windows-gaming-force`
- **What it does**: Forces deployment even if a VM with the same configuration already exists

### `make deploy-windows-gaming-auto`
- **Description**: Auto-deploy Windows Gaming VM with RTX 2080 Ti detection
- **Usage**: `make deploy-windows-gaming-auto`
- **What it does**: Runs the specialized script that auto-detects RTX 2080 Ti PCI IDs and deploys

### `make deploy-windows-gaming-custom`
- **Description**: Deploy Windows Gaming VM with custom configuration
- **Usage**: `make deploy-windows-gaming-custom GPU_PCI_ID=01:00.0 AUDIO_PCI_ID=01:00.1 MEMORY=65536 CORES=12 HOSTNAME=gaming-rig`
- **Variables**:
  - `GPU_PCI_ID`: Primary GPU PCI ID (e.g., "01:00.0")
  - `AUDIO_PCI_ID`: GPU Audio PCI ID (e.g., "01:00.1")
  - `MEMORY`: Memory in MB (e.g., 65536 for 64GB)
  - `CORES`: Number of CPU cores (e.g., 12)
  - `HOSTNAME`: VM hostname (e.g., "gaming-rig")

## VM Management Targets

### `make windows-gaming-start`
- **Description**: Start Windows Gaming VM
- **Usage**: `make windows-gaming-start VM_ID=300`
- **Required**: `VM_ID` variable with the VM ID number

### `make windows-gaming-stop`
- **Description**: Stop Windows Gaming VM
- **Usage**: `make windows-gaming-stop VM_ID=300`
- **Required**: `VM_ID` variable with the VM ID number

### `make windows-gaming-restart`
- **Description**: Restart Windows Gaming VM
- **Usage**: `make windows-gaming-restart VM_ID=300`
- **Required**: `VM_ID` variable with the VM ID number

### `make windows-gaming-status`
- **Description**: Show Windows Gaming VM status and configuration
- **Usage**: `make windows-gaming-status VM_ID=300`
- **Required**: `VM_ID` variable with the VM ID number
- **What it shows**: VM status, CPU cores, memory, GPU passthrough config

### `make windows-gaming-console`
- **Description**: Connect to Windows Gaming VM console
- **Usage**: `make windows-gaming-console VM_ID=300`
- **Required**: `VM_ID` variable with the VM ID number

### `make windows-gaming-destroy`
- **Description**: Destroy Windows Gaming VM (DESTRUCTIVE)
- **Usage**: `make windows-gaming-destroy VM_ID=300 CONFIRM=yes`
- **Required**: 
  - `VM_ID` variable with the VM ID number
  - `CONFIRM=yes` for safety confirmation

## GPU Passthrough Utilities

### `make find-gpu-pci-ids`
- **Description**: Find RTX 2080 Ti PCI IDs for GPU passthrough
- **Usage**: `make find-gpu-pci-ids`
- **What it does**: Runs the script to detect RTX 2080 Ti and show PCI IDs for configuration

### `make check-gpu-passthrough`
- **Description**: Check GPU passthrough status and IOMMU configuration
- **Usage**: `make check-gpu-passthrough`
- **What it does**: Validates IOMMU, VFIO modules, and GPU binding status

## Help Targets

### `make help-windows-gaming`
- **Description**: Show Windows Gaming VM deployment examples
- **Usage**: `make help-windows-gaming`
- **What it shows**: Complete workflow, examples, specifications, and documentation links

## Integration Points

### Added to Main Help
- Windows Gaming VM section now appears in `make help`
- Shows quick commands for deployment and management

### Added to Advanced Help
- Windows Gaming VM management commands appear in `make help-advanced`
- VM management examples included

### Added to Syntax Check
- Windows Gaming playbook included in `make syntax-check`
- Validates playbook syntax with other deployments

## Quick Reference

```bash
# Complete deployment workflow
make find-gpu-pci-ids                    # Find RTX 2080 Ti PCI IDs
make deploy-windows-gaming-auto          # Auto-deploy with detection
make windows-gaming-status VM_ID=300     # Check deployment status
make windows-gaming-start VM_ID=300      # Start the VM
make windows-gaming-console VM_ID=300    # Connect to console

# Custom deployment
make deploy-windows-gaming-custom GPU_PCI_ID=01:00.0 AUDIO_PCI_ID=01:00.1

# VM management
make windows-gaming-stop VM_ID=300       # Stop VM
make windows-gaming-restart VM_ID=300    # Restart VM

# Utilities
make check-gpu-passthrough               # Check GPU passthrough setup
make help-windows-gaming                 # Show complete help
```

All targets follow the existing Makefile conventions and integrate seamlessly with the current homeserver project structure.
