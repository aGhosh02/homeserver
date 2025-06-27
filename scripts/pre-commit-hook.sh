#!/bin/bash
# Pre-commit hook for Ansible quality control
# Place this in .git/hooks/pre-commit and make it executable

set -e

echo "🔍 Running pre-commit checks..."

# Check if ansible-lint is available
if ! command -v ansible-lint &> /dev/null; then
    echo "⚠️  ansible-lint not found. Installing..."
    pip install ansible-lint
fi

# Run syntax check
echo "📝 Checking Ansible syntax..."
cd ansible
for playbook in playbooks/*.yml; do
    if [[ -f "$playbook" ]]; then
        ansible-playbook --syntax-check "$playbook"
    fi
done

# Run ansible-lint
echo "🔍 Running ansible-lint..."
ansible-lint playbooks/ roles/ || {
    echo "❌ Ansible lint issues found. Please fix before committing."
    exit 1
}

# Check for vault files that might be unencrypted
echo "🔐 Checking vault security..."
if grep -r "vault_" inventories/ | grep -v "!vault"; then
    echo "⚠️  Found potential unencrypted vault variables. Please encrypt sensitive data."
fi

# Check for hardcoded passwords or secrets (basic check)
echo "🔒 Checking for hardcoded secrets..."
if grep -r -i "password\|secret\|key" inventories/ playbooks/ roles/ | grep -v -E "(vault|template|example|comment)"; then
    echo "⚠️  Found potential hardcoded secrets. Please use vault encryption."
fi

echo "✅ Pre-commit checks passed!"
