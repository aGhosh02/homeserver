# Docker LXC Container Setup

This document describes the Docker LXC container role for the Proxmox homeserver setup.

## Overview

The `docker_lxc` role creates and configures a privileged LXC container on Proxmox VE with Docker and Docker Compose installed. This container is designed to host multiple Docker services with proper data persistence and resource allocation.

## Features

- **Privileged LXC Container**: Required for Docker to function properly
- **Docker Engine**: Latest stable version with proper configuration
- **Docker Compose**: For orchestrating multi-container applications
- **Resource Management**: 4 CPU cores, 16GB RAM with dynamic ballooning
- **Storage**: 100GB+ thin-provisioned disk with bind-mounted host directories
- **Data Persistence**: Host directories mounted for Docker data and volumes
- **Network Configuration**: Flexible network setup with DHCP or static IP
- **Sample Applications**: Pre-configured sample services including Portainer

## Requirements

### Host Requirements
- Proxmox VE 7.0+ 
- Minimum 2 CPU cores (4 recommended)
- Minimum 8GB RAM (16GB+ recommended for container allocation)
- Minimum 50GB free disk space
- Network bridge (default: vmbr0)

### Software Requirements
- Ansible 2.9+
- LXC template: `debian-12-standard_12.7-1_amd64.tar.zst`

## Configuration

### Default Configuration

The role uses the following default configuration in `defaults/main.yml`:

```yaml
docker_lxc:
  vmid: ""  # Auto-generated
  hostname: "docker-host"
  disk_size: "100G"
  cpu:
    cores: 4
    limit: 4
  memory: 16384  # MB (16GB)
  network:
    bridge: "vmbr0"
    ip: "dhcp"
  privileged: true
  onboot: true
  nesting: true
  keyctl: true
```

### Override Configuration

You can override the default configuration by setting `docker_lxc_override` in your playbook:

```yaml
docker_lxc_override:
  hostname: "docker-services"
  memory: 32768  # 32GB
  cpu:
    cores: 8
  network:
    ip: "192.168.1.100/24"
    gateway: "192.168.1.1"
```

## Deployment

### Using the Playbook

Deploy the Docker LXC container using the dedicated playbook:

```bash
ansible-playbook -i inventories/production playbooks/deploy-docker-lxc.yml
```

### Using the Management Script

Use the provided management script for easier deployment:

```bash
# Deploy with default settings
./scripts/docker-lxc.sh deploy

# Deploy with custom settings
./scripts/docker-lxc.sh deploy \
  --hostname docker-services \
  --memory 32768 \
  --cpu-cores 8 \
  --disk-size 200G \
  --ip 192.168.1.100/24
```

### Manual Integration

Add the role to your existing playbook:

```yaml
- hosts: proxmox
  roles:
    - role: docker_lxc
      vars:
        docker_lxc_override:
          hostname: "my-docker-host"
          memory: 16384
```

## Usage

### Container Management

```bash
# Start container
./scripts/docker-lxc.sh start --container-id 200

# Stop container  
./scripts/docker-lxc.sh stop --container-id 200

# Enter container shell
./scripts/docker-lxc.sh enter --container-id 200

# Check status
./scripts/docker-lxc.sh status --container-id 200

# List Docker containers inside LXC
./scripts/docker-lxc.sh list-containers --container-id 200
```

### Docker Operations

Once inside the container:

```bash
# Check Docker status
systemctl status docker

# Start sample services
cd /root/docker-samples
docker-compose up -d

# View running containers
docker ps

# View logs
docker logs portainer
docker logs sample-nginx

# Stop services
docker-compose down
```

## Data Persistence

The container uses bind mounts for data persistence:

### Host Directories
- `/opt/docker-data` → Container `/var/lib/docker` (Docker daemon data)
- `/opt/docker-volumes` → Container `/opt/volumes` (Application volumes)

### Container Directories
- `/root/docker-samples/` - Sample Docker Compose configurations
- `/var/lib/docker/` - Docker daemon data (persistent)
- `/opt/volumes/` - Application volume storage (persistent)

## Sample Applications

The role installs sample applications in `/root/docker-samples/`:

### Portainer (Docker Management UI)
- **URL**: `http://[container-ip]:9000`
- **Purpose**: Web-based Docker management interface
- **Data**: Stored in `/opt/volumes/portainer`

### Sample Nginx
- **URL**: `http://[container-ip]:8080`  
- **Purpose**: Example web server
- **Data**: Served from `/opt/volumes/nginx`

### Starting Sample Services

```bash
cd /root/docker-samples
docker-compose up -d
```

## Network Configuration

### DHCP (Default)
```yaml
network:
  ip: "dhcp"
  bridge: "vmbr0"
```

### Static IP
```yaml
network:
  ip: "192.168.1.100/24"
  gateway: "192.168.1.1" 
  bridge: "vmbr0"
```

### VLAN Tagging
```yaml
network:
  ip: "192.168.10.100/24"
  bridge: "vmbr0"
  vlan_tag: "10"
```

## Security Considerations

### Privileged Container
The container runs in privileged mode to support Docker. This means:
- Container has full access to host devices
- Required for Docker's proper operation
- Ensure proper network isolation
- Regularly update container and host systems

### Docker Security
- Docker daemon configured with logging limits
- Non-root users can be added to docker group
- Container networking isolated by default

## Troubleshooting

### Container Creation Issues

**Problem**: Container creation fails with insufficient resources
```bash
# Check available resources
free -h
nproc
df -h
```

**Problem**: Network bridge doesn't exist
```bash
# List available bridges
ip link show type bridge

# Create bridge if needed (example)
ip link add name vmbr1 type bridge
```

### Docker Issues

**Problem**: Docker service won't start
```bash
# Enter container and check logs
pct enter [container-id]
systemctl status docker
journalctl -u docker
```

**Problem**: Permission denied errors
```bash
# Add user to docker group
usermod -aG docker $USER
# Or run with sudo
sudo docker ps
```

### Storage Issues

**Problem**: No space left on device
```bash
# Check container storage usage
pct exec [container-id] -- df -h

# Check host storage
df -h /opt/docker-data
df -h /opt/docker-volumes

# Clean up Docker
pct exec [container-id] -- docker system prune -f
```

## Monitoring

### Container Health
```bash
# Check container status
pct status [container-id]

# Check resource usage
pct exec [container-id] -- htop
```

### Docker Health
```bash
# Check Docker system info
pct exec [container-id] -- docker system info

# Check Docker events
pct exec [container-id] -- docker events
```

## Backup and Recovery

### Container Backup
```bash
# Create snapshot
pct snapshot [container-id] backup-$(date +%Y%m%d)

# Backup to file
vzdump [container-id] --storage local --compress gzip
```

### Data Backup
```bash
# Backup Docker volumes
tar -czf docker-volumes-backup.tar.gz /opt/docker-volumes/

# Backup Docker data
tar -czf docker-data-backup.tar.gz /opt/docker-data/
```

## Advanced Configuration

### Custom Docker Daemon Configuration

Modify the Docker daemon configuration in your playbook:

```yaml
docker_config:
  daemon_config:
    log_driver: "syslog"
    storage_driver: "devicemapper"
    insecure_registries:
      - "registry.local:5000"
```

### Additional Mount Points

Add custom mount points:

```yaml
docker_lxc_override:
  mount_points:
    - mp: "mp2"
      host_path: "/srv/media"
      container_path: "/media"
      backup: false
    - mp: "mp3"
      host_path: "/srv/config"
      container_path: "/config"
      backup: true
```

### Resource Limits

Configure CPU and memory limits:

```yaml
docker_lxc_override:
  cpu:
    cores: 8
    limit: 6  # Limit to 6 cores maximum
  memory: 32768
  memory_swap: 32768
```

## Integration with Other Services

### Home Assistant Integration
The Docker LXC can host Home Assistant and related services:

```yaml
# In your docker-compose.yml
services:
  homeassistant:
    image: homeassistant/home-assistant:stable
    container_name: homeassistant
    ports:
      - "8123:8123"
    volumes:
      - /opt/volumes/homeassistant:/config
    restart: unless-stopped
```

### Media Server Integration
Host media services like Plex, Jellyfin:

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    ports:
      - "8096:8096"
    volumes:
      - /opt/volumes/jellyfin:/config
      - /media:/media:ro
    restart: unless-stopped
```

## Performance Tuning

### Container Performance
- Allocate sufficient CPU cores for workload
- Use SSD storage for Docker data directory
- Enable thin provisioning for disk efficiency
- Configure appropriate memory limits

### Docker Performance
- Use multi-stage builds for smaller images
- Implement proper health checks
- Use Docker secrets for sensitive data
- Regularly clean up unused resources

## Migration and Scaling

### Container Migration
```bash
# Stop container
pct stop [container-id]

# Migrate to another node
pct migrate [container-id] [target-node]
```

### Scaling Resources
```bash
# Increase memory
pct set [container-id] --memory 32768

# Add CPU cores  
pct set [container-id] --cores 8

# Resize disk
pct resize [container-id] rootfs +50G
```

This completes the Docker LXC container setup documentation. The role provides a robust foundation for hosting containerized services on your Proxmox homeserver.
