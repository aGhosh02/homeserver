#!/bin/bash

# Simple test for space conversion with your actual value
echo "Testing space conversion logic..."
echo

# Your actual available space value
SPACE="855855104"

echo "Input: $SPACE"
echo "Detected as: pure number (no unit)"
echo "Assumption: KB (Proxmox default)"

# Convert KB to GB
SPACE_GB=$((SPACE / 1024 / 1024))
echo "Conversion: $SPACE KB / 1024 / 1024 = $SPACE_GB GB"

echo
if [ $SPACE_GB -ge 114 ]; then
    echo "✅ PASS: $SPACE_GB GB >= 114 GB required"
else
    echo "❌ FAIL: $SPACE_GB GB < 114 GB required"
fi

echo
echo "Testing POSIX-compatible logic..."

# Test the same logic as in the Ansible task
space="$SPACE"
if echo "$space" | grep -q '^[0-9]\+$'; then
    echo "✅ Pattern match: pure number detected"
    result=$((space / 1024 / 1024))
    echo "✅ Conversion result: $result GB"
else
    echo "❌ Pattern match failed"
fi

echo
echo "This logic should work in the Ansible task now."
