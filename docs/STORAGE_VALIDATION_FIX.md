# Storage Validation Error Fix Guide

## Issue: "No suitable storage location found for Windows Gaming VM"

This error occurs when the Ansible playbook cannot find a suitable Proxmox storage location for the Windows Gaming VM.

## Diagnosis Steps

### 1. Run Storage Debug Script on Proxmox Host

```bash
# Copy and run this on your Proxmox host
./scripts/debug-storage.sh
```

### 2. Manual Storage Check

Run these commands on your Proxmox host:

```bash
# Check all storage
pvesm status

# Check storage that supports VM images
pvesm status --content images

# Check active storage for VM images
pvesm status --content images | awk 'NR>1 && $2=="active" {print $1}'
```

### 3. Expected Output

You should see something like:
```
Name      Type    Status  Total    Used  Available  %
local     dir     active  96.77GB  67%   31.97GB    33.02%
local-lvm lvmthin active  200.00GB 45%   110.00GB   55.00%
```

## Common Causes and Solutions

### Cause 1: No Storage Configured for VM Images

**Check**: `pvesm status --content images` returns empty

**Solution**:
1. Open Proxmox Web Interface
2. Go to **Datacenter** → **Storage**
3. Select existing storage (e.g., `local-lvm`)
4. Click **Edit**
5. In **Content**, ensure **Disk image** is checked
6. Click **OK**

### Cause 2: Storage Not Active

**Check**: Storage shows status other than "active"

**Solution**:
1. Check storage connectivity/mounting
2. Restart storage service if needed
3. Check disk space and health

### Cause 3: Insufficient Space

**Check**: Available space < 114GB (100GB VM + 4GB EFI + 10GB buffer)

**Solution**:
1. Clean up old VMs/containers
2. Expand storage
3. Add additional storage location

### Cause 4: Storage Type Not Supported

**Check**: Storage type doesn't support VM images

**Solution**:
1. Use LVM, LVM-thin, ZFS, or directory storage
2. Configure proper storage backend

## Quick Fixes

### Fix 1: Enable Disk Images on Local-LVM

```bash
# On Proxmox host - enable disk images on local-lvm
pvesm set local-lvm --content images,rootdir
```

### Fix 2: Create Directory Storage

```bash
# Create a directory storage location
mkdir -p /var/lib/vz/windows-vms
pvesm add dir windows-storage --path /var/lib/vz/windows-vms --content images
```

### Fix 3: Manual Storage Location Override

If you have a specific storage location, override it in the deployment:

```bash
# Deploy with specific storage location
make deploy-windows-gaming-custom STORAGE_LOCATION=local-lvm

# Or modify the defaults file:
# ansible/roles/windows_gaming_vm/defaults/main.yml
# Set: windows_vm.storage.location: "local-lvm"
```

## Verification

After making changes, verify with:

```bash
# Run storage debug
make debug-storage

# Or manually check
pvesm status --content images | awk 'NR>1 && $2=="active" {print $1}'
```

## Re-run Deployment

Once storage is fixed:

```bash
# Test deployment
make deploy-windows-gaming-check

# Full deployment
make deploy-windows-gaming
```

## Still Having Issues?

1. Check Proxmox logs: `journalctl -u pvestatd`
2. Verify disk health: `smartctl -a /dev/sdX`
3. Check filesystem: `df -h`
4. Ensure Proxmox services are running: `systemctl status pve*`
