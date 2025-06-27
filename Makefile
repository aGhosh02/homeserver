# Makefile for Proxmox Homeserver Ansible Project
# Enhanced version with improved functionality and formatting

# Colors for better output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
WHITE := \033[37m
RESET := \033[0m

.PHONY: help setup run validate maintenance clean install-deps lint test security-check

# Default target
help: ## Show this help message
	@echo "$(CYAN)🏠 Proxmox Homeserver Ansible Management$(RESET)"
	@echo "$(WHITE)Available targets:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)📋 Quick Start:$(RESET)"
	@echo "  1. $(WHITE)make setup$(RESET)       - Install requirements"
	@echo "  2. $(WHITE)make validate$(RESET)    - Check connectivity"  
	@echo "  3. $(WHITE)make run$(RESET)         - Full deployment"
	@echo ""

setup: install-deps ## Install dependencies and setup environment
	@echo "$(BLUE)🔧 Setting up Ansible environment...$(RESET)"
	cd ansible && ansible-galaxy install -r requirements.yml --force
	@echo "$(GREEN)✅ Setup complete!$(RESET)"

install-deps: ## Install required Ansible collections
	@echo "$(BLUE)📦 Installing Ansible dependencies...$(RESET)"
	cd ansible && ansible-galaxy collection install -r requirements.yml --force
	@echo "$(GREEN)✅ Dependencies installed!$(RESET)"

run: ## Run the main site playbook
	@echo "🚀 Running Proxmox setup..."
	cd ansible && ansible-playbook playbooks/site.yml

run-base: ## Run only base configuration
	@echo "🔧 Running base configuration..."
	cd ansible && ansible-playbook playbooks/site.yml --tags base

run-network: ## Run only network configuration  
	@echo "🌐 Running network configuration..."
	cd ansible && ansible-playbook playbooks/site.yml --tags networking

run-gpu: ## Run only GPU passthrough configuration
	@echo "🎮 Running GPU passthrough configuration..."
	cd ansible && ansible-playbook playbooks/site.yml --tags gpu

validate: ## Validate system configuration
	@echo "✅ Validating system configuration..."
	cd ansible && ansible-playbook playbooks/validate.yml

maintenance: ## Run maintenance tasks
	@echo "🔧 Running maintenance tasks..."
	cd ansible && ansible-playbook playbooks/maintenance.yml

dry-run: ## Run playbook in dry-run mode
	@echo "🔍 Running dry-run..."
	cd ansible && ansible-playbook playbooks/site.yml --check --diff

lint: ## Lint Ansible files
	@echo "🔍 Linting Ansible files..."
	find . -name "*.yml" -o -name "*.yaml" | grep -E "(playbook|role)" | xargs ansible-lint || true

clean: ## Clean temporary files and logs
	@echo "🧹 Cleaning temporary files..."
	rm -f /tmp/ansible.log
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

syntax-check: ## Check syntax of all playbooks
	@echo "📝 Checking syntax..."
	cd ansible && ansible-playbook playbooks/site.yml --syntax-check
	cd ansible && ansible-playbook playbooks/validate.yml --syntax-check
	cd ansible && ansible-playbook playbooks/maintenance.yml --syntax-check

inventory: ## Show inventory information
	@echo "📋 Inventory information:"
	cd ansible && ansible-inventory --list

ping: ## Ping all hosts
	@echo "🏓 Pinging all hosts..."
	cd ansible && ansible all -m ping

facts: ## Gather facts from all hosts
	@echo "📊 Gathering facts..."
	cd ansible && ansible all -m setup --tree /tmp/facts

# Vault operations
encrypt-vault: ## Encrypt sensitive variables with Ansible Vault
	@echo "$(YELLOW)🔐 Encrypting vault file...$(RESET)"
	cd ansible && ansible-vault encrypt inventories/production/group_vars/all/vault.yml

decrypt-vault: ## Decrypt vault file for editing
	@echo "$(YELLOW)🔓 Decrypting vault file...$(RESET)"
	cd ansible && ansible-vault decrypt inventories/production/group_vars/all/vault.yml

edit-vault: ## Edit encrypted vault file
	@echo "$(YELLOW)✏️  Editing vault file...$(RESET)"
	cd ansible && ansible-vault edit inventories/production/group_vars/all/vault.yml

# Testing and validation
test: validate lint syntax-check ## Run all tests and validations
	@echo "$(GREEN)🧪 Running comprehensive tests...$(RESET)"

backup-configs: maintenance ## Backup current configurations (alias for maintenance)

update-system: maintenance ## Update system packages (alias for maintenance)
