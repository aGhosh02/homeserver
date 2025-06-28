#!/bin/bash

# Test script to verify storage detection with your specific output
# Run this on your Proxmox host to test the fixed detection logic

echo "Testing storage detection with your Proxmox configuration..."
echo

# Your actual output:
# Name             Type     Status           Total            Used       Available        %
# local-lvm     lvmthin     active       855855104               0       855855104    0.00%

echo "=== Testing storage location detection ==="
echo "Command: pvesm status --content images | awk 'NR>1 && \$3==\"active\" {print \$1}'"
DETECTED_STORAGE=$(pvesm status --content images | awk 'NR>1 && $3=="active" {print $1}')
echo "Detected storage: '$DETECTED_STORAGE'"

if [ -n "$DETECTED_STORAGE" ]; then
    echo "✅ Storage detection: SUCCESS"
    
    echo
    echo "=== Testing available space detection ==="
    echo "Command: pvesm status --storage \"$DETECTED_STORAGE\" | awk 'NR>1 {print \$6}'"
    AVAILABLE_SPACE=$(pvesm status --storage "$DETECTED_STORAGE" | awk 'NR>1 {print $6}')
    echo "Available space: '$AVAILABLE_SPACE'"
    
    if [ -n "$AVAILABLE_SPACE" ] && [ "$AVAILABLE_SPACE" != "0" ]; then
        # Convert to GB (assuming KB input)
        SPACE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
        echo "Available space in GB: ${SPACE_GB}GB"
        
        if [ $SPACE_GB -ge 114 ]; then
            echo "✅ Space validation: SUCCESS (${SPACE_GB}GB >= 114GB required)"
        else
            echo "❌ Space validation: FAILED (${SPACE_GB}GB < 114GB required)"
        fi
    else
        echo "❌ Space detection: FAILED"
    fi
else
    echo "❌ Storage detection: FAILED"
    echo
    echo "Raw output from 'pvesm status --content images':"
    pvesm status --content images
fi

echo
echo "=== Full storage status ==="
pvesm status --content images

echo
echo "Test complete. If storage detection shows SUCCESS, the Windows Gaming VM deployment should work."
