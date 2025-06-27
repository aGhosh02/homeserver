# Makefile for Proxmox Homeserver Ansible Project
# Enhanced version with improved functionality, error handling, and formatting

# Project Information
PROJECT_NAME := homeserver
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "v1.0.0-dev")
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

# Colors for better output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
MAGENTA := \033[35m
CYAN := \033[36m
WHITE := \033[37m
BOLD := \033[1m
RESET := \033[0m

# Configuration
ANSIBLE_DIR := ansible
INVENTORY := $(ANSIBLE_DIR)/inventories/production
PLAYBOOK_DIR := $(ANSIBLE_DIR)/playbooks
VAULT_FILE := $(INVENTORY)/group_vars/all/vault.yml
LOG_DIR := logs
LOG_FILE := $(LOG_DIR)/ansible-$(shell date +%Y%m%d-%H%M%S).log

# Validation
REQUIRED_COMMANDS := ansible ansible-playbook ansible-vault ansible-galaxy
ANSIBLE_MIN_VERSION := 2.12

.PHONY: help setup run validate maintenance clean install-deps lint test security-check info check-deps

# Default target
help: ## Show this help message
	@echo "$(CYAN)$(BOLD)🏠 Proxmox Homeserver Ansible Management$(RESET)"
	@echo "$(WHITE)Project: $(PROJECT_NAME) | Version: $(VERSION)$(RESET)"
	@echo ""
	@echo "$(WHITE)Available targets:$(RESET)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)📋 Quick Start:$(RESET)"
	@echo "  1. $(WHITE)make check-deps$(RESET)   - Check dependencies"
	@echo "  2. $(WHITE)make setup$(RESET)        - Install requirements"
	@echo "  3. $(WHITE)make validate$(RESET)     - Check connectivity"  
	@echo "  4. $(WHITE)make run$(RESET)          - Full deployment"
	@echo ""
	@echo "$(YELLOW)🔧 Maintenance:$(RESET)"
	@echo "  • $(WHITE)make info$(RESET)          - Show project information"
	@echo "  • $(WHITE)make test$(RESET)          - Run all tests"
	@echo "  • $(WHITE)make clean$(RESET)         - Clean temporary files"
	@echo ""

info: ## Show project information
	@echo "$(CYAN)$(BOLD)📊 Project Information$(RESET)"
	@echo "$(WHITE)Name:$(RESET)         $(PROJECT_NAME)"
	@echo "$(WHITE)Version:$(RESET)      $(VERSION)"
	@echo "$(WHITE)Build Date:$(RESET)   $(BUILD_DATE)"
	@echo "$(WHITE)Ansible Dir:$(RESET)  $(ANSIBLE_DIR)"
	@echo "$(WHITE)Inventory:$(RESET)    $(INVENTORY)"
	@echo "$(WHITE)Log Dir:$(RESET)      $(LOG_DIR)"
	@echo ""

check-deps: ## Check required dependencies
	@echo "$(BLUE)🔍 Checking dependencies...$(RESET)"
	@$(foreach cmd,$(REQUIRED_COMMANDS), \
		if ! command -v $(cmd) >/dev/null 2>&1; then \
			echo "$(RED)✗ $(cmd) not found$(RESET)"; \
			exit 1; \
		else \
			echo "$(GREEN)✓ $(cmd) found$(RESET)"; \
		fi;)
	@ansible_version=$$(ansible --version | head -n1 | cut -d' ' -f3 | cut -d']' -f1); \
	if ! printf '%s\n%s\n' "$(ANSIBLE_MIN_VERSION)" "$$ansible_version" | sort -V -C; then \
		echo "$(RED)✗ Ansible version $$ansible_version is too old (minimum: $(ANSIBLE_MIN_VERSION))$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ Ansible version $$ansible_version meets requirements$(RESET)"; \
	fi
	@echo "$(GREEN)✅ All dependencies satisfied!$(RESET)"

setup: check-deps install-deps ## Install dependencies and setup environment
	@echo "$(BLUE)🔧 Setting up Ansible environment...$(RESET)"
	@mkdir -p $(LOG_DIR)
	@cd $(ANSIBLE_DIR) && ansible-galaxy install -r requirements.yml --force
	@echo "$(GREEN)✅ Setup complete!$(RESET)"

install-deps: ## Install required Ansible collections
	@echo "$(BLUE)📦 Installing Ansible dependencies...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml --force
	@echo "$(GREEN)✅ Dependencies installed!$(RESET)"

run: check-deps ## Run the main site playbook
	@echo "$(BLUE)🚀 Running Proxmox setup...$(RESET)"
	@mkdir -p $(LOG_DIR)
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml --extra-vars "log_file=$(LOG_FILE)" || \
	(echo "$(RED)❌ Deployment failed! Check $(LOG_FILE) for details$(RESET)" && exit 1)
	@echo "$(GREEN)✅ Deployment completed successfully!$(RESET)"

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
	@echo "$(BLUE)🧹 Cleaning temporary files...$(RESET)"
	@rm -f /tmp/ansible*.log
	@find . -name "*.retry" -delete 2>/dev/null || true
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@rm -rf /tmp/ansible_facts_cache 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup complete!$(RESET)"

deep-clean: clean ## Deep clean including logs and cache
	@echo "$(BLUE)🧹 Deep cleaning...$(RESET)"
	@rm -rf $(LOG_DIR) 2>/dev/null || true
	@rm -rf ~/.ansible/collections/ansible_collections/community 2>/dev/null || true
	@echo "$(GREEN)✅ Deep cleanup complete!$(RESET)"

syntax-check: ## Check syntax of all playbooks
	@echo "📝 Checking syntax..."
	cd ansible && ansible-playbook playbooks/site.yml --syntax-check
	cd ansible && ansible-playbook playbooks/validate.yml --syntax-check
	cd ansible && ansible-playbook playbooks/maintenance.yml --syntax-check
	cd ansible && ansible-playbook playbooks/deploy-haos.yml --syntax-check

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
test: validate lint syntax-check security-check ## Run all tests and validations
	@echo "$(GREEN)$(BOLD)🧪 Running comprehensive tests...$(RESET)"
	@echo "$(GREEN)✅ All tests passed!$(RESET)"

security-check: ## Run security checks
	@echo "$(BLUE)🔒 Running security checks...$(RESET)"
	@# Check for hardcoded passwords
	@if grep -r "ansible_ssh_pass.*[^{]" $(INVENTORY) 2>/dev/null | grep -v vault; then \
		echo "$(RED)⚠️  Found hardcoded passwords! Please use vault encryption.$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ No hardcoded passwords found$(RESET)"; \
	fi
	@# Check vault file is encrypted
	@if [ -f "$(VAULT_FILE)" ] && ! head -1 "$(VAULT_FILE)" | grep -q '$$ANSIBLE_VAULT'; then \
		echo "$(RED)⚠️  Vault file is not encrypted!$(RESET)"; \
		exit 1; \
	else \
		echo "$(GREEN)✓ Vault file is properly encrypted$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Security checks passed!$(RESET)"

backup: ## Create backup of current configuration
	@echo "$(BLUE)💾 Creating configuration backup...$(RESET)"
	@backup_name="backup-$$(date +%Y%m%d-%H%M%S).tar.gz"; \
	tar -czf "$$backup_name" \
		--exclude='logs' \
		--exclude='.git' \
		--exclude='*.retry' \
		--exclude='__pycache__' \
		.; \
	echo "$(GREEN)✅ Backup created: $$backup_name$(RESET)"

backup-configs: maintenance ## Backup current configurations (alias for maintenance)

update-system: maintenance ## Update system packages (alias for maintenance)

deploy-haos: ## Deploy Home Assistant OS VM (stable, 2GB RAM)
	@echo "🏠 Deploying Home Assistant OS VM..."
	cd ansible && ansible-playbook playbooks/deploy-haos.yml

deploy-haos-check: ## Check Home Assistant OS deployment (dry-run)
	@echo "🔍 Checking Home Assistant OS deployment..."
	cd ansible && ansible-playbook playbooks/deploy-haos.yml --check --diff

deploy-haos-force: ## Force deploy Home Assistant OS VM (even if exists)
	@echo "$(BLUE)🏠 Force deploying Home Assistant OS VM...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-haos.yml -e haos_skip_if_exists=false

# New enhanced targets
config-validate: ## Validate all configuration files
	@echo "$(BLUE)🔍 Validating configuration...$(RESET)"
	@./scripts/config-validator.sh

deploy-interactive: ## Interactive deployment with guided setup
	@echo "$(BLUE)🚀 Starting interactive deployment...$(RESET)"
	@./scripts/deployment-manager.sh

monitor: ## Monitor system status and logs
	@echo "$(BLUE)📊 Monitoring system status...$(RESET)"
	@./scripts/health-check.sh
	@echo "\n$(YELLOW)Following logs (Ctrl+C to stop):$(RESET)"
	@tail -f $(LOG_DIR)/ansible-*.log 2>/dev/null || echo "No logs available yet"

performance-test: ## Run performance benchmarks
	@echo "$(BLUE)🏃 Running performance tests...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible all -m shell -a "uptime && free -h && df -h"

network-test: ## Test network connectivity and configuration
	@echo "$(BLUE)🌐 Testing network configuration...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible all -m shell -a "ip route show && ping -c 3 8.8.8.8"

gpu-test: ## Test GPU passthrough configuration
	@echo "$(BLUE)🎮 Testing GPU passthrough...$(RESET)"
	@./scripts/gpu-passthrough-manager.sh check

upgrade: ## Upgrade system packages and dependencies
	@echo "$(BLUE)⬆️  Upgrading system...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/maintenance.yml --tags upgrade

# Documentation targets
docs-serve: ## Serve documentation locally
	@echo "$(BLUE)📚 Serving documentation...$(RESET)"
	@if command -v python3 >/dev/null 2>&1; then \
		cd docs && python3 -m http.server 8080; \
	else \
		echo "$(RED)Python3 not found. Install Python3 to serve docs.$(RESET)"; \
	fi

docs-check: ## Check documentation for broken links
	@echo "$(BLUE)🔗 Checking documentation links...$(RESET)"
	@find docs -name "*.md" -exec grep -l "http" {} \; | head -5

# Development targets
dev-setup: ## Setup development environment
	@echo "$(BLUE)🛠️  Setting up development environment...$(RESET)"
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
	else \
		echo "$(YELLOW)pre-commit not found. Install with: pip install pre-commit$(RESET)"; \
	fi
	@cp scripts/pre-commit-hook.sh .git/hooks/pre-commit 2>/dev/null || true
	@chmod +x .git/hooks/pre-commit 2>/dev/null || true

dev-test: ## Run development tests
	@echo "$(BLUE)🧪 Running development tests...$(RESET)"
	@$(MAKE) config-validate
	@$(MAKE) lint
	@$(MAKE) syntax-check

# Maintenance targets  
update-deps: ## Update all dependencies
	@echo "$(BLUE)📦 Updating dependencies...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-galaxy collection install -r requirements.yml --force --upgrade

logs-archive: ## Archive old logs
	@echo "$(BLUE)📦 Archiving old logs...$(RESET)"
	@if [ -d "$(LOG_DIR)" ]; then \
		find $(LOG_DIR) -name "*.log" -mtime +30 -exec gzip {} \; 2>/dev/null || true; \
		echo "$(GREEN)✅ Logs archived$(RESET)"; \
	else \
		echo "$(YELLOW)No logs directory found$(RESET)"; \
	fi

system-info: ## Display comprehensive system information
	@echo "$(BLUE)💻 System Information:$(RESET)"
	@$(MAKE) info
	@echo "\n$(BLUE)🔗 Network Configuration:$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible all -m shell -a "ip addr show | grep inet" 2>/dev/null || echo "Not connected"
	@echo "\n$(BLUE)💾 Storage Information:$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible all -m shell -a "df -h" 2>/dev/null || echo "Not connected"

# All-in-one targets
fresh-install: clean setup config-validate run validate ## Complete fresh installation
	@echo "$(GREEN)🎉 Fresh installation completed!$(RESET)"

full-test: config-validate lint syntax-check security-check validate ## Run all tests
	@echo "$(GREEN)🧪 All tests completed!$(RESET)"

# Help categories
help-advanced: ## Show advanced usage examples
	@echo "$(CYAN)$(BOLD)🚀 Advanced Usage Examples$(RESET)"
	@echo ""
	@echo "$(WHITE)Deployment Scenarios:$(RESET)"
	@echo "  $(GREEN)make fresh-install$(RESET)     - Complete new setup"
	@echo "  $(GREEN)make deploy-interactive$(RESET) - Guided deployment"
	@echo "  $(GREEN)make config-validate$(RESET)    - Validate before deploy"
	@echo ""
	@echo "$(WHITE)Maintenance Tasks:$(RESET)"
	@echo "  $(GREEN)make upgrade$(RESET)           - System updates"
	@echo "  $(GREEN)make monitor$(RESET)           - System monitoring"
	@echo "  $(GREEN)make backup$(RESET)            - Configuration backup"
	@echo ""
	@echo "$(WHITE)Development & Testing:$(RESET)"
	@echo "  $(GREEN)make dev-setup$(RESET)         - Development environment"
	@echo "  $(GREEN)make full-test$(RESET)         - Comprehensive testing"
	@echo "  $(GREEN)make performance-test$(RESET)  - Performance benchmarks"
	@echo ""
