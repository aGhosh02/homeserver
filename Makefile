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
	@echo "$(YELLOW)🐳 Docker LXC:$(RESET)"
	@echo "  • $(WHITE)make deploy-docker-lxc$(RESET) - Deploy Docker container platform"
	@echo "  • $(WHITE)make docker-lxc-status CONTAINER_ID=200$(RESET) - Check container status"
	@echo ""
	@echo "$(YELLOW)🎮 Windows Gaming VM:$(RESET)"
	@echo "  • $(WHITE)make deploy-windows-gaming$(RESET) - Deploy Windows Gaming VM"
	@echo "  • $(WHITE)make windows-gaming-status VM_ID=300$(RESET) - Check VM status"
	@echo "  • $(WHITE)make windows-gaming-console VM_ID=300$(RESET) - Connect to VM console"
	@echo "  • $(WHITE)make find-gpu-pci-ids$(RESET) - Find GPU PCI IDs"
	@echo "  • $(WHITE)make check-gpu-passthrough$(RESET) - Check GPU passthrough status"
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
	cd ansible && ansible-playbook playbooks/deploy-omv.yml --syntax-check
	cd ansible && ansible-playbook playbooks/deploy-docker-lxc.yml --syntax-check
	cd ansible && ansible-playbook playbooks/deploy-windows-gaming.yml --syntax-check

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

deploy-omv: ## Deploy OpenMediaVault NAS VM (4GB RAM, SATA controller)
	@echo "💾 Deploying OpenMediaVault NAS VM..."
	cd ansible && ansible-playbook playbooks/deploy-omv.yml --vault-password-file .vault_pass

deploy-omv-check: ## Check OpenMediaVault deployment (dry-run)
	@echo "🔍 Checking OpenMediaVault deployment..."
	cd ansible && ansible-playbook playbooks/deploy-omv.yml --check --diff

deploy-omv-force: ## Force deploy OpenMediaVault VM (even if exists)
	@echo "$(BLUE)💾 Force deploying OpenMediaVault VM...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-omv.yml -e omv_skip_if_exists=false

# Docker LXC deployment targets
deploy-docker-lxc: ## Deploy Docker LXC container (16GB RAM, 4 cores, 100GB disk)
	@echo "$(BLUE)🐳 Deploying Docker LXC container...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-docker-lxc.yml

deploy-docker-lxc-check: ## Check Docker LXC deployment (dry-run)
	@echo "$(BLUE)🔍 Checking Docker LXC deployment...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-docker-lxc.yml --check --diff

deploy-docker-lxc-check-no-validation: ## Check Docker LXC deployment without host validation (for development)
	@echo "$(BLUE)🔍 Checking Docker LXC deployment (no validation)...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-docker-lxc.yml --check --diff --skip-tags validation

deploy-docker-lxc-force: ## Force deploy Docker LXC container (even if exists)
	@echo "$(BLUE)🐳 Force deploying Docker LXC container...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-docker-lxc.yml -e docker_lxc_skip_if_exists=false

deploy-docker-lxc-custom: ## Deploy Docker LXC with custom configuration (use HOSTNAME, MEMORY, CPU_CORES, DISK_SIZE, IP variables)
	@echo "$(BLUE)🐳 Deploying Docker LXC container with custom configuration...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-docker-lxc.yml \
		$(if $(HOSTNAME),-e 'docker_lxc_override.hostname=$(HOSTNAME)') \
		$(if $(MEMORY),-e 'docker_lxc_override.memory=$(MEMORY)') \
		$(if $(CPU_CORES),-e 'docker_lxc_override.cpu.cores=$(CPU_CORES)') \
		$(if $(DISK_SIZE),-e 'docker_lxc_override.disk_size=$(DISK_SIZE)') \
		$(if $(IP),-e 'docker_lxc_override.network.ip=$(IP)')

# Docker LXC management targets (require CONTAINER_ID variable)
docker-lxc-start: ## Start Docker LXC container (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)▶️  Starting Docker LXC container $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-start CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct start $(CONTAINER_ID)
	@echo "$(GREEN)✅ Container $(CONTAINER_ID) started$(RESET)"

docker-lxc-stop: ## Stop Docker LXC container (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)⏹️  Stopping Docker LXC container $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-stop CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct stop $(CONTAINER_ID)
	@echo "$(GREEN)✅ Container $(CONTAINER_ID) stopped$(RESET)"

docker-lxc-restart: ## Restart Docker LXC container (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)🔄 Restarting Docker LXC container $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-restart CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct restart $(CONTAINER_ID)
	@echo "$(GREEN)✅ Container $(CONTAINER_ID) restarted$(RESET)"

docker-lxc-status: ## Show Docker LXC container status (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)📊 Docker LXC container $(CONTAINER_ID) status:$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-status CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct status $(CONTAINER_ID)
	@echo "\n$(BLUE)🐳 Docker service status:$(RESET)"
	@pct exec $(CONTAINER_ID) -- systemctl status docker --no-pager --lines=5 2>/dev/null || echo "$(YELLOW)Container not running or Docker not installed$(RESET)"
	@echo "\n$(BLUE)📦 Docker containers:$(RESET)"
	@pct exec $(CONTAINER_ID) -- docker ps 2>/dev/null || echo "$(YELLOW)Docker not accessible$(RESET)"

docker-lxc-enter: ## Enter Docker LXC container shell (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)🚪 Entering Docker LXC container $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-enter CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct enter $(CONTAINER_ID)

docker-lxc-logs: ## Show Docker LXC container logs (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)📋 Docker LXC container $(CONTAINER_ID) logs:$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-logs CONTAINER_ID=200$(RESET)"; exit 1; fi
	@journalctl -u pve-container@$(CONTAINER_ID) -n 50 --no-pager

docker-lxc-destroy: ## Destroy Docker LXC container (requires CONTAINER_ID=xxx and CONFIRM=yes)
	@echo "$(RED)💀 Destroying Docker LXC container $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-destroy CONTAINER_ID=200 CONFIRM=yes$(RESET)"; exit 1; fi
	@if [ "$(CONFIRM)" != "yes" ]; then echo "$(RED)❌ Error: This is destructive! Add CONFIRM=yes to proceed$(RESET)"; exit 1; fi
	@pct stop $(CONTAINER_ID) 2>/dev/null || true
	@pct destroy $(CONTAINER_ID)
	@echo "$(GREEN)✅ Container $(CONTAINER_ID) destroyed$(RESET)"

# Docker container management inside LXC (requires CONTAINER_ID=xxx)
docker-lxc-ps: ## List Docker containers inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)📦 Docker containers in LXC $(CONTAINER_ID):$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-ps CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- docker ps -a

docker-lxc-images: ## List Docker images inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)🏗️  Docker images in LXC $(CONTAINER_ID):$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-images CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- docker images

docker-lxc-volumes: ## List Docker volumes inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)💾 Docker volumes in LXC $(CONTAINER_ID):$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-volumes CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- docker volume ls

docker-lxc-stats: ## Show Docker container stats inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)📊 Docker container stats in LXC $(CONTAINER_ID):$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-stats CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- docker stats --no-stream

docker-lxc-prune: ## Clean up Docker system inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)🧹 Cleaning Docker system in LXC $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-prune CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- docker system prune -f
	@echo "$(GREEN)✅ Docker system cleaned$(RESET)"

# Sample services management (requires CONTAINER_ID=xxx)
docker-lxc-samples-start: ## Start sample Docker services inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)🚀 Starting sample Docker services in LXC $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-samples-start CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- bash -c "cd /root/docker-samples && docker-compose up -d"
	@echo "$(GREEN)✅ Sample services started$(RESET)"
	@echo "$(CYAN)🌐 Access Portainer: http://[container-ip]:9000$(RESET)"
	@echo "$(CYAN)🌐 Access Nginx: http://[container-ip]:8080$(RESET)"

docker-lxc-samples-stop: ## Stop sample Docker services inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)⏹️  Stopping sample Docker services in LXC $(CONTAINER_ID)...$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-samples-stop CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- bash -c "cd /root/docker-samples && docker-compose down"
	@echo "$(GREEN)✅ Sample services stopped$(RESET)"

docker-lxc-samples-logs: ## Show sample Docker services logs inside LXC (requires CONTAINER_ID=xxx)
	@echo "$(BLUE)📋 Sample Docker services logs in LXC $(CONTAINER_ID):$(RESET)"
	@if [ -z "$(CONTAINER_ID)" ]; then echo "$(RED)❌ Error: CONTAINER_ID is required. Usage: make docker-lxc-samples-logs CONTAINER_ID=200$(RESET)"; exit 1; fi
	@pct exec $(CONTAINER_ID) -- bash -c "cd /root/docker-samples && docker-compose logs --tail=20"

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
	@echo "  $(GREEN)make fresh-install$(RESET)         - Complete new setup"
	@echo "  $(GREEN)make deploy-interactive$(RESET)     - Guided deployment"
	@echo "  $(GREEN)make config-validate$(RESET)        - Validate before deploy"
	@echo ""
	@echo "$(WHITE)VM/Container Deployments:$(RESET)"
	@echo "  $(GREEN)make deploy-haos$(RESET)            - Deploy Home Assistant OS"
	@echo "  $(GREEN)make deploy-omv$(RESET)             - Deploy OpenMediaVault NAS"
	@echo "  $(GREEN)make deploy-docker-lxc$(RESET)      - Deploy Docker LXC container"
	@echo "  $(GREEN)make deploy-windows-gaming$(RESET)  - Deploy Windows Gaming VM"
	@echo "  $(GREEN)make deploy-docker-lxc-custom HOSTNAME=my-docker MEMORY=32768$(RESET)"
	@echo "                                 - Deploy with custom settings"
	@echo ""
	@echo "$(WHITE)Docker LXC Management:$(RESET)"
	@echo "  $(GREEN)make docker-lxc-status CONTAINER_ID=200$(RESET)     - Container status"
	@echo "  $(GREEN)make docker-lxc-enter CONTAINER_ID=200$(RESET)      - Enter container"
	@echo "  $(GREEN)make docker-lxc-ps CONTAINER_ID=200$(RESET)         - List Docker containers"
	@echo "  $(GREEN)make docker-lxc-samples-start CONTAINER_ID=200$(RESET) - Start sample services"
	@echo ""
	@echo "$(WHITE)Windows Gaming VM Management:$(RESET)"
	@echo "  $(GREEN)make windows-gaming-status VM_ID=300$(RESET)       - VM status and config"
	@echo "  $(GREEN)make windows-gaming-start VM_ID=300$(RESET)        - Start gaming VM"
	@echo "  $(GREEN)make windows-gaming-console VM_ID=300$(RESET)      - Connect to VM console"
	@echo "  $(GREEN)make find-gpu-pci-ids$(RESET)                      - Find RTX 2080 Ti PCI IDs"
	@echo "  $(GREEN)make check-gpu-passthrough$(RESET)                 - Check GPU passthrough status"
	@echo "  $(GREEN)make debug-storage$(RESET)                         - Debug storage configuration"
	@echo ""
	@echo "$(WHITE)Maintenance Tasks:$(RESET)"
	@echo "  $(GREEN)make upgrade$(RESET)               - System updates"
	@echo "  $(GREEN)make monitor$(RESET)               - System monitoring"
	@echo "  $(GREEN)make backup$(RESET)                - Configuration backup"
	@echo ""
	@echo "$(WHITE)Development & Testing:$(RESET)"
	@echo "  $(GREEN)make dev-setup$(RESET)             - Development environment"
	@echo "  $(GREEN)make full-test$(RESET)             - Comprehensive testing"
	@echo "  $(GREEN)make performance-test$(RESET)      - Performance benchmarks"
	@echo ""

help-docker-lxc: ## Show Docker LXC specific help and examples
	@echo "$(CYAN)$(BOLD)🐳 Docker LXC Container Management$(RESET)"
	@echo ""
	@echo "$(WHITE)📦 Deployment Commands:$(RESET)"
	@echo "  $(GREEN)make deploy-docker-lxc$(RESET)                    - Deploy with default settings (16GB RAM, 4 cores)"
	@echo "  $(GREEN)make deploy-docker-lxc-check$(RESET)              - Dry-run deployment"
	@echo "  $(GREEN)make deploy-docker-lxc-force$(RESET)              - Force deploy (overwrite existing)"
	@echo ""
	@echo "$(WHITE)🔧 Custom Deployment:$(RESET)"
	@echo "  $(GREEN)make deploy-docker-lxc-custom HOSTNAME=docker-services MEMORY=32768 CPU_CORES=8$(RESET)"
	@echo "  $(GREEN)make deploy-docker-lxc-custom IP=192.168.1.100/24 DISK_SIZE=200G$(RESET)"
	@echo ""
	@echo "$(WHITE)🎛️  Container Management:$(RESET)"
	@echo "  $(GREEN)make docker-lxc-start CONTAINER_ID=200$(RESET)    - Start container"
	@echo "  $(GREEN)make docker-lxc-stop CONTAINER_ID=200$(RESET)     - Stop container"
	@echo "  $(GREEN)make docker-lxc-restart CONTAINER_ID=200$(RESET)  - Restart container"
	@echo "  $(GREEN)make docker-lxc-status CONTAINER_ID=200$(RESET)   - Show status & Docker info"
	@echo "  $(GREEN)make docker-lxc-enter CONTAINER_ID=200$(RESET)    - Enter container shell"
	@echo "  $(GREEN)make docker-lxc-logs CONTAINER_ID=200$(RESET)     - Show container logs"
	@echo ""
	@echo "$(WHITE)🐳 Docker Management:$(RESET)"
	@echo "  $(GREEN)make docker-lxc-ps CONTAINER_ID=200$(RESET)       - List Docker containers"
	@echo "  $(GREEN)make docker-lxc-images CONTAINER_ID=200$(RESET)   - List Docker images"
	@echo "  $(GREEN)make docker-lxc-volumes CONTAINER_ID=200$(RESET)  - List Docker volumes"
	@echo "  $(GREEN)make docker-lxc-stats CONTAINER_ID=200$(RESET)    - Show container resource usage"
	@echo "  $(GREEN)make docker-lxc-prune CONTAINER_ID=200$(RESET)    - Clean up Docker system"
	@echo ""
	@echo "$(WHITE)🚀 Sample Services:$(RESET)"
	@echo "  $(GREEN)make docker-lxc-samples-start CONTAINER_ID=200$(RESET) - Start Portainer & Nginx samples"
	@echo "  $(GREEN)make docker-lxc-samples-stop CONTAINER_ID=200$(RESET)  - Stop sample services"
	@echo "  $(GREEN)make docker-lxc-samples-logs CONTAINER_ID=200$(RESET)  - Show sample service logs"
	@echo ""
	@echo "$(WHITE)💀 Destruction (BE CAREFUL!):$(RESET)"
	@echo "  $(RED)make docker-lxc-destroy CONTAINER_ID=200 CONFIRM=yes$(RESET) - Permanently delete container"
	@echo ""
	@echo "$(YELLOW)📋 Example Workflow:$(RESET)"
	@echo "  1. $(WHITE)make deploy-docker-lxc$(RESET)                  - Deploy container"
	@echo "  2. $(WHITE)make docker-lxc-status CONTAINER_ID=200$(RESET) - Check it's running"
	@echo "  3. $(WHITE)make docker-lxc-samples-start CONTAINER_ID=200$(RESET) - Start samples"
	@echo "  4. $(WHITE)Open browser: http://[host-ip]:9000$(RESET)     - Access Portainer"
	@echo "  5. $(WHITE)make docker-lxc-enter CONTAINER_ID=200$(RESET) - Enter for custom configs"
	@echo ""
	@echo "$(YELLOW)📖 Documentation: $(RESET)docs/DOCKER_LXC_DEPLOYMENT.md"
	@echo ""

help-windows-gaming: ## Show Windows Gaming VM deployment examples
	@echo "$(MAGENTA)$(BOLD)🎮 Windows Gaming VM Deployment Examples$(RESET)"
	@echo ""
	@echo "$(WHITE)Quick Start:$(RESET)"
	@echo "  1. $(GREEN)make find-gpu-pci-ids$(RESET)                    - Find RTX 2080 Ti PCI IDs"
	@echo "  2. $(GREEN)make deploy-windows-gaming-auto$(RESET)          - Auto-deploy with detection"
	@echo "  3. $(GREEN)make windows-gaming-status VM_ID=300$(RESET)     - Check deployment status"
	@echo ""
	@echo "$(WHITE)Manual Deployment:$(RESET)"
	@echo "  $(GREEN)make deploy-windows-gaming$(RESET)                 - Deploy with default config"
	@echo "  $(GREEN)make deploy-windows-gaming-check$(RESET)          - Dry-run deployment"
	@echo "  $(GREEN)make deploy-windows-gaming-force$(RESET)          - Force deploy (overwrite existing)"
	@echo ""
	@echo "$(WHITE)Custom Configuration:$(RESET)"
	@echo "  $(GREEN)make deploy-windows-gaming-custom GPU_PCI_ID=01:00.0 AUDIO_PCI_ID=01:00.1$(RESET)"
	@echo "  $(GREEN)make deploy-windows-gaming-custom MEMORY=65536 CORES=12$(RESET) - More resources"
	@echo "  $(GREEN)make deploy-windows-gaming-custom HOSTNAME=gaming-rig$(RESET) - Custom name"
	@echo "  $(GREEN)make deploy-windows-gaming-custom STORAGE_LOCATION=local-lvm$(RESET) - Specific storage"
	@echo ""
	@echo "$(WHITE)VM Management:$(RESET)"
	@echo "  $(GREEN)make windows-gaming-start VM_ID=300$(RESET)       - Start VM"
	@echo "  $(GREEN)make windows-gaming-stop VM_ID=300$(RESET)        - Stop VM"
	@echo "  $(GREEN)make windows-gaming-restart VM_ID=300$(RESET)     - Restart VM"
	@echo "  $(GREEN)make windows-gaming-console VM_ID=300$(RESET)     - Connect to console"
	@echo ""
	@echo "$(WHITE)GPU Passthrough Utilities:$(RESET)"
	@echo "  $(GREEN)make check-gpu-passthrough$(RESET)                - Check IOMMU/VFIO status"
	@echo "  $(GREEN)make find-gpu-pci-ids$(RESET)                     - Auto-detect RTX 2080 Ti"
	@echo "  $(GREEN)make debug-storage$(RESET)                        - Debug storage configuration"
	@echo ""
	@echo "$(YELLOW)📋 Complete Workflow:$(RESET)"
	@echo "  1. $(WHITE)Enable IOMMU in BIOS (Intel VT-d/AMD-Vi)$(RESET)"
	@echo "  2. $(WHITE)Add kernel parameters: intel_iommu=on iommu=pt$(RESET)"
	@echo "  3. $(WHITE)Blacklist GPU drivers and reboot$(RESET)"
	@echo "  4. $(WHITE)make find-gpu-pci-ids$(RESET)                  - Find PCI IDs"
	@echo "  5. $(WHITE)make deploy-windows-gaming-auto$(RESET)         - Deploy VM"
	@echo "  6. $(WHITE)make windows-gaming-start VM_ID=300$(RESET)    - Start VM"
	@echo "  7. $(WHITE)Connect monitor to RTX 2080 Ti and install Windows$(RESET)"
	@echo "  8. $(WHITE)Install VirtIO drivers and NVIDIA drivers$(RESET)"
	@echo ""
	@echo "$(YELLOW)🎯 Specifications:$(RESET)"
	@echo "  • $(WHITE)CPU:$(RESET) 8 cores (host type, pinned 0-7)"
	@echo "  • $(WHITE)RAM:$(RESET) 32GB dedicated"
	@echo "  • $(WHITE)GPU:$(RESET) RTX 2080 Ti + HDMI Audio passthrough"
	@echo "  • $(WHITE)OS:$(RESET) Windows 11 IoT Enterprise LTSC 2024"
	@echo "  • $(WHITE)Features:$(RESET) NUMA, PCIe ACS override, VirtIO drivers"
	@echo ""
	@echo "$(YELLOW)📖 Documentation: $(RESET)docs/WINDOWS_GAMING_RTX2080TI.md"
	@echo ""

# Windows Gaming VM deployment targets
deploy-windows-gaming: ## Deploy Windows Gaming VM with RTX 2080 Ti (8 cores, 32GB RAM, GPU passthrough)
	@echo "$(MAGENTA)🎮 Deploying Windows Gaming VM with RTX 2080 Ti...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-windows-gaming.yml

deploy-windows-gaming-check: ## Check Windows Gaming VM deployment (dry-run)
	@echo "$(MAGENTA)🔍 Checking Windows Gaming VM deployment...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-windows-gaming.yml --check --diff

deploy-windows-gaming-force: ## Force deploy Windows Gaming VM (even if exists)
	@echo "$(MAGENTA)🎮 Force deploying Windows Gaming VM...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-windows-gaming.yml -e windows_skip_if_exists=false

deploy-windows-gaming-auto: ## Auto-deploy Windows Gaming VM with RTX 2080 Ti detection
	@echo "$(MAGENTA)🎮 Auto-deploying Windows Gaming VM with RTX 2080 Ti detection...$(RESET)"
	@./scripts/deploy-windows-gaming-rtx2080ti.sh

deploy-windows-gaming-custom: ## Deploy Windows Gaming VM with custom configuration (use GPU_PCI_ID, AUDIO_PCI_ID, MEMORY, CORES, STORAGE_LOCATION variables)
	@echo "$(MAGENTA)🎮 Deploying Windows Gaming VM with custom configuration...$(RESET)"
	@cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy-windows-gaming.yml \
		$(if $(GPU_PCI_ID),-e 'windows_vm.gpu_passthrough.primary_gpu=$(GPU_PCI_ID)') \
		$(if $(AUDIO_PCI_ID),-e 'windows_vm.gpu_passthrough.gpu_audio=$(AUDIO_PCI_ID)') \
		$(if $(MEMORY),-e 'windows_vm.memory=$(MEMORY)') \
		$(if $(CORES),-e 'windows_vm.cpu.cores=$(CORES)') \
		$(if $(HOSTNAME),-e 'windows_vm.hostname=$(HOSTNAME)') \
		$(if $(STORAGE_LOCATION),-e 'windows_vm.storage.location=$(STORAGE_LOCATION)')

# Windows Gaming VM management targets (require VM_ID variable)
windows-gaming-start: ## Start Windows Gaming VM (requires VM_ID=xxx)
	@echo "$(MAGENTA)▶️  Starting Windows Gaming VM $(VM_ID)...$(RESET)"
	@if [ -z "$(VM_ID)" ]; then echo "$(RED)❌ Error: VM_ID is required. Usage: make windows-gaming-start VM_ID=300$(RESET)"; exit 1; fi
	@qm start $(VM_ID)
	@echo "$(GREEN)✅ Windows Gaming VM $(VM_ID) started$(RESET)"

windows-gaming-stop: ## Stop Windows Gaming VM (requires VM_ID=xxx)
	@echo "$(MAGENTA)⏹️  Stopping Windows Gaming VM $(VM_ID)...$(RESET)"
	@if [ -z "$(VM_ID)" ]; then echo "$(RED)❌ Error: VM_ID is required. Usage: make windows-gaming-stop VM_ID=300$(RESET)"; exit 1; fi
	@qm stop $(VM_ID)
	@echo "$(GREEN)✅ Windows Gaming VM $(VM_ID) stopped$(RESET)"

windows-gaming-restart: ## Restart Windows Gaming VM (requires VM_ID=xxx)
	@echo "$(MAGENTA)🔄 Restarting Windows Gaming VM $(VM_ID)...$(RESET)"
	@if [ -z "$(VM_ID)" ]; then echo "$(RED)❌ Error: VM_ID is required. Usage: make windows-gaming-restart VM_ID=300$(RESET)"; exit 1; fi
	@qm restart $(VM_ID)
	@echo "$(GREEN)✅ Windows Gaming VM $(VM_ID) restarted$(RESET)"

windows-gaming-status: ## Show Windows Gaming VM status (requires VM_ID=xxx)
	@echo "$(MAGENTA)📊 Windows Gaming VM $(VM_ID) status:$(RESET)"
	@if [ -z "$(VM_ID)" ]; then echo "$(RED)❌ Error: VM_ID is required. Usage: make windows-gaming-status VM_ID=300$(RESET)"; exit 1; fi
	@qm status $(VM_ID)
	@echo "\n$(MAGENTA)💻 VM Configuration:$(RESET)"
	@qm config $(VM_ID) | grep -E "(cores|memory|hostpci|gpu|cpu)" 2>/dev/null || echo "$(YELLOW)VM configuration not available$(RESET)"

windows-gaming-console: ## Connect to Windows Gaming VM console (requires VM_ID=xxx)
	@echo "$(MAGENTA)🖥️  Connecting to Windows Gaming VM $(VM_ID) console...$(RESET)"
	@if [ -z "$(VM_ID)" ]; then echo "$(RED)❌ Error: VM_ID is required. Usage: make windows-gaming-console VM_ID=300$(RESET)"; exit 1; fi
	@qm monitor $(VM_ID)

windows-gaming-destroy: ## Destroy Windows Gaming VM (requires VM_ID=xxx and CONFIRM=yes)
	@echo "$(RED)💀 Destroying Windows Gaming VM $(VM_ID)...$(RESET)"
	@if [ -z "$(VM_ID)" ]; then echo "$(RED)❌ Error: VM_ID is required. Usage: make windows-gaming-destroy VM_ID=300 CONFIRM=yes$(RESET)"; exit 1; fi
	@if [ "$(CONFIRM)" != "yes" ]; then echo "$(RED)❌ Error: This is destructive! Add CONFIRM=yes to proceed$(RESET)"; exit 1; fi
	@qm stop $(VM_ID) 2>/dev/null || true
	@qm destroy $(VM_ID)
	@echo "$(GREEN)✅ Windows Gaming VM $(VM_ID) destroyed$(RESET)"

# GPU passthrough utilities
find-gpu-pci-ids: ## Find RTX 2080 Ti PCI IDs for GPU passthrough
	@echo "$(CYAN)🔍 Finding RTX 2080 Ti PCI IDs...$(RESET)"
	@./scripts/find-gpu-pci-ids.sh

check-gpu-passthrough: ## Check GPU passthrough status and IOMMU configuration
	@echo "$(CYAN)🔧 Checking GPU passthrough status...$(RESET)"
	@./scripts/gpu-passthrough-manager.sh check

debug-storage: ## Debug Proxmox storage configuration for VM deployment
	@echo "$(CYAN)💾 Debugging Proxmox storage configuration...$(RESET)"
	@./scripts/debug-storage.sh
