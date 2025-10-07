#!/bin/bash

# Docker Engine Installation Script for WSL2
# Installs Docker Engine, configures systemd, and creates verification script

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Output functions
print_header() {
    echo -e "\n${MAGENTA}$(printf '=%.0s' {1..80})${NC}"
    echo -e "${MAGENTA} $1${NC}"
    echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ Error: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Check if running in WSL2
check_wsl2() {
    print_info "Checking if running in WSL2..."
    
    if ! grep -qi microsoft /proc/version; then
        print_error "This script must be run inside WSL2"
        exit 1
    fi
    
    if ! grep -qi wsl2 /proc/version 2>/dev/null; then
        if grep -qi microsoft /proc/version; then
            print_warning "This appears to be WSL1. WSL2 is strongly recommended."
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    print_success "Running in WSL2"
}

# Remove existing Docker installations
remove_old_docker() {
    print_header "Removing Old Docker Installations"
    
    print_info "Checking for existing Docker installations..."
    
    local old_packages=(
        "docker"
        "docker-engine"
        "docker.io"
        "containerd"
        "runc"
        "docker-doc"
        "docker-compose"
        "podman-docker"
    )
    
    local found_packages=()
    for pkg in "${old_packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$pkg"; then
            found_packages+=("$pkg")
        fi
    done
    
    if [ ${#found_packages[@]} -eq 0 ]; then
        print_success "No conflicting Docker packages found"
    else
        print_warning "Found old Docker packages: ${found_packages[*]}"
        print_info "Removing old packages..."
        sudo apt-get remove -y "${found_packages[@]}" 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
        print_success "Old Docker packages removed"
    fi
}

# Update system
update_system() {
    print_header "Updating System Packages"
    
    print_info "Updating package lists..."
    sudo apt-get update
    
    print_info "Upgrading existing packages..."
    sudo apt-get upgrade -y
    
    print_success "System updated"
}

# Install prerequisites
install_prerequisites() {
    print_header "Installing Prerequisites"
    
    local packages=(
        "ca-certificates"
        "curl"
        "gnupg"
        "lsb-release"
    )
    
    print_info "Installing required packages..."
    sudo apt-get install -y "${packages[@]}"
    
    print_success "Prerequisites installed"
}

# Install Docker Engine
install_docker() {
    print_header "Installing Docker Engine"
    
    # Create keyrings directory
    print_info "Setting up Docker repository..."
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Add Docker's official GPG key
    print_info "Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    print_info "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update apt and install Docker
    print_info "Updating package lists..."
    sudo apt-get update
    
    print_info "Installing Docker packages (this may take a few minutes)..."
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    print_success "Docker Engine installed"
    
    # Show installed versions
    echo -e "\n${CYAN}Installed versions:${NC}"
    docker --version
    docker compose version
}

# Configure user permissions
configure_user() {
    print_header "Configuring User Permissions"
    
    print_info "Adding $USER to docker group..."
    
    # Check if user is already in docker group
    if groups $USER | grep -q '\bdocker\b'; then
        print_success "User $USER already in docker group"
    else
        sudo usermod -aG docker $USER
        print_success "User $USER added to docker group"
        print_warning "You'll need to log out and back in for group changes to take effect"
    fi
}

# Configure systemd
configure_systemd() {
    print_header "Configuring Systemd"
    
    local wsl_conf="/etc/wsl.conf"
    
    # Check if systemd is already enabled
    if [ -f "$wsl_conf" ] && grep -q "^systemd=true" "$wsl_conf"; then
        print_success "Systemd already enabled in wsl.conf"
        return 0
    fi
    
    print_info "Enabling systemd in WSL2..."
    
    # Backup existing wsl.conf if it exists
    if [ -f "$wsl_conf" ]; then
        sudo cp "$wsl_conf" "${wsl_conf}.backup"
        print_info "Backed up existing wsl.conf"
    fi
    
    # Add or update systemd configuration
    if [ -f "$wsl_conf" ] && grep -q "^\[boot\]" "$wsl_conf"; then
        # [boot] section exists, check if systemd line exists
        if grep -q "^systemd=" "$wsl_conf"; then
            sudo sed -i 's/^systemd=.*/systemd=true/' "$wsl_conf"
        else
            sudo sed -i '/^\[boot\]/a systemd=true' "$wsl_conf"
        fi
    else
        # No [boot] section, add it
        echo -e "\n[boot]\nsystemd=true" | sudo tee -a "$wsl_conf" > /dev/null
    fi
    
    print_success "Systemd enabled in wsl.conf"
}

# Create verification script
create_verification_script() {
    print_header "Creating Verification Script"
    
    local verify_script="$HOME/verify-docker.sh"
    
    cat > "$verify_script" << 'EOF'
#!/bin/bash

# Docker Verification Script
# Run this after restarting WSL with: wsl --shutdown (from PowerShell)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo -e "\n${MAGENTA}$(printf '=%.0s' {1..80})${NC}"
    echo -e "${MAGENTA} $1${NC}"
    echo -e "${MAGENTA}$(printf '=%.0s' {1..80})${NC}\n"
}

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ Error: $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ $1${NC}"; }

print_header "Docker Installation Verification"

# Check if systemd is running
print_info "Checking systemd status..."
if ! systemctl is-system-running --quiet 2>/dev/null; then
    print_error "Systemd is not running!"
    echo -e "${YELLOW}Did you restart WSL? Run from PowerShell: wsl --shutdown${NC}"
    exit 1
fi
print_success "Systemd is running"

# Enable and start Docker service
print_info "Configuring Docker service..."
sudo systemctl enable docker.service 2>/dev/null || true
sudo systemctl start docker.service 2>/dev/null || true

# Check Docker service status
if systemctl is-active --quiet docker.service; then
    print_success "Docker service is running"
else
    print_error "Docker service is not running"
    echo "Attempting to start Docker service..."
    sudo systemctl start docker.service
fi

# Show Docker version
echo -e "\n${CYAN}Docker Version:${NC}"
docker --version

echo -e "\n${CYAN}Docker Compose Version:${NC}"
docker compose version

# Test Docker
print_header "Testing Docker"
print_info "Running hello-world container..."
if docker run --rm hello-world > /dev/null 2>&1; then
    print_success "Docker is working correctly!"
    echo -e "\n${GREEN}${BOLD}Docker test output:${NC}"
    docker run --rm hello-world
else
    print_error "Docker test failed"
    echo "Try running: sudo systemctl status docker"
    exit 1
fi

# Show Docker info
print_header "Docker System Information"
docker info 2>/dev/null | head -n 20

# Helpful aliases
print_header "Optional: Helpful Aliases"
echo -e "${CYAN}Add these to your ~/.bashrc or ~/.zshrc:${NC}\n"
cat << 'ALIASES'
# Docker aliases
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dimg='docker images'
alias dlog='docker logs'
alias dexec='docker exec -it'

# Docker cleanup
alias docker-clean='docker system prune -af --volumes'
ALIASES

# Next steps
print_header "Installation Complete!"
echo -e "${GREEN}✓ Docker Engine is installed and running${NC}"
echo -e "${GREEN}✓ Docker Compose is available${NC}"
echo -e "${GREEN}✓ Systemd is configured for auto-start${NC}\n"

echo -e "${CYAN}Quick Start Commands:${NC}"
echo "  docker run hello-world          # Test Docker"
echo "  docker ps                        # List running containers"
echo "  docker images                    # List images"
echo "  docker compose up               # Start compose services"
echo ""
echo -e "${CYAN}Docker will now start automatically with WSL!${NC}"
EOF

    chmod +x "$verify_script"
    print_success "Verification script created: $verify_script"
}

# Main function
main() {
    print_header "Docker Engine Installation for WSL2"
    echo -e "${CYAN}This script will install Docker Engine and configure it for automatic startup${NC}\n"
    
    # Confirm execution
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi
    
    # Run installation steps
    check_wsl2
    remove_old_docker
    update_system
    install_prerequisites
    install_docker
    configure_user
    configure_systemd
    create_verification_script
    
    # Final instructions
    print_header "Installation Complete!"
    
    print_success "Docker Engine has been installed successfully"
    
    echo -e "\n${YELLOW}${BOLD}IMPORTANT NEXT STEPS:${NC}\n"
    echo -e "${CYAN}1. Shut down WSL from PowerShell (Windows):${NC}"
    echo -e "   ${MAGENTA}wsl --shutdown${NC}\n"
    
    echo -e "${CYAN}2. Restart WSL by opening Ubuntu again${NC}\n"
    
    echo -e "${CYAN}3. Run the verification script in your home directory:${NC}"
    echo -e "   ${MAGENTA}~/verify-docker.sh${NC}\n"
    
    echo -e "${YELLOW}The WSL shutdown is required for systemd to start properly.${NC}"
    echo -e "${YELLOW}After restarting, Docker will start automatically with WSL!${NC}\n"
}

# Run main function
main
