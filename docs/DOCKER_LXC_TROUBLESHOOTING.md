# Docker LXC Troubleshooting Guide

## Common Issues and Solutions

### 1. Container Creation Errors

#### Problem: "Unknown option: privileged"
**Error:**
```
Unknown option: privileged
400 unable to parse option
```

**Solution:**
The correct way to create a privileged container is by omitting the `--unprivileged` flag, not by using `--privileged 1`.

**Fixed Command:**
```bash
# For privileged container (default)
pct create 200 template.tar.zst --hostname container

# For unprivileged container
pct create 200 template.tar.zst --hostname container --unprivileged 1
```

#### Problem: "cifs: not found" in features
**Error:**
```
/bin/sh: 1: cifs: not found
```

**Solution:**
The `mount=nfs;cifs` feature was being interpreted as a shell command. Removed this feature as it's not essential for Docker functionality.

**Fixed Configuration:**
```yaml
features:
  - "nesting=1"
  - "keyctl=1"
  # Removed: - "mount=nfs;cifs"
```

### 2. Storage Validation Errors

#### Problem: "jq: not found"
**Error:**
```
/bin/sh: 1: jq: not found
Unable to flush stdout: Broken pipe
```

**Solution:**
Replaced `jq` dependency with pure shell commands using `grep` and `cut`.

**Fixed Command:**
```bash
# Old (requires jq):
pvesh get /nodes/host/storage/local/status --output-format json | jq -r '.avail'

# New (no dependencies):
pvesh get /nodes/host/storage/local/status | grep -o '"avail":[0-9]*' | cut -d':' -f2
```

### 3. Recursive Variable Errors

#### Problem: "recursive loop detected in template string"
**Error:**
```
recursive loop detected in template string: {{ docker_lxc_override }}
```

**Solution:**
Removed redundant variable assignment in role invocation.

**Fixed Playbook:**
```yaml
# Wrong:
roles:
  - role: docker_lxc
    vars:
      docker_lxc_override: "{{ docker_lxc_override }}"

# Correct:
roles:
  - role: docker_lxc
```

### 4. Validation Failures in Development

#### Problem: Proxmox validation fails in non-Proxmox environments
**Error:**
```
This role must be run on a Proxmox VE host
```

**Solution:**
Made validations configurable and disabled them for development/testing.

**Configuration:**
```yaml
docker_lxc_validation_override:
  check_proxmox_host: false
  check_host_resources: false
  check_storage_space: false
```

### 5. Root Filesystem Format Errors

#### Problem: "rootfs: invalid format"
**Error:**
```
rootfs: invalid format
pct: unable to parse options
```

**Solution:**
The `thin=1` option is not valid in the `--rootfs` parameter. Thin provisioning is controlled at the storage level, not in the container creation command.

**Fixed Command:**
```bash
# Wrong:
--rootfs local-lvm:100G,thin=1

# Correct:
--rootfs local-lvm:100G
```

**Note:** Thin provisioning is automatically enabled for most Proxmox storage types (like LVM-Thin) and doesn't need to be specified in the container creation command.

#### Problem: "no such logical volume" errors
**Error:**
```
unable to create CT 200 - no such logical volume pve/100G
```

**Solution:**
This error occurs when the storage format is incorrect for LVM storage. The issue is that Proxmox LVM storage expects the size without the 'G' suffix.

**Fixes:**
```bash
# Wrong format:
--rootfs local-lvm:100G

# Correct format:
--rootfs local-lvm:100
```

The automation now automatically strips the 'G' suffix when using LVM storage.

**Root cause:** Proxmox interprets `local-lvm:100G` as trying to find a logical volume named "100G" instead of allocating 100GB of space.

## Best Practices

### 1. Container Configuration
- Use privileged containers for Docker (default behavior)
- Enable `nesting=1` and `keyctl=1` features for Docker support
- Avoid unnecessary mount features that may cause issues

### 2. Storage Management
- Use thin provisioning for efficient disk usage
- Ensure sufficient disk space before deployment
- Use reliable storage backends (local-lvm, ZFS, etc.)

### 3. Development vs Production
- Disable validations for development environments
- Enable full validations for production deployments
- Use dry-run mode to test configurations

### 4. Error Handling
- Check logs in `/var/log/ansible-deployment/`
- Use `make deploy-docker-lxc-check` for dry-run testing
- Enable verbose output with `-vvv` for debugging

## Useful Commands

### Testing
```bash
# Dry-run deployment
make deploy-docker-lxc-check

# Deploy without validations (development)
make deploy-docker-lxc-check-no-validation

# Full deployment
make deploy-docker-lxc
```

### Container Management
```bash
# Check container status
pct status 200

# Enter container
pct enter 200

# Check Docker service
pct exec 200 -- systemctl status docker

# View container logs
journalctl -u pve-container@200
```

### Debugging
```bash
# Check Proxmox storage
pvesh get /storage

# List container templates
pveam list local

# Check available resources
free -h && nproc && df -h
```

This troubleshooting guide should help resolve common issues encountered during Docker LXC deployment.
