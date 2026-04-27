#!/usr/bin/env bash

# Hardware detection helper for NixOS configurations
# Detects GPU, CPU, and other hardware to suggest appropriate NixOS modules

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_suggestion() {
    echo -e "${BLUE}→${NC} $1"
}

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "This script is only for Linux/NixOS systems."
    exit 1
fi

print_header "Hardware Detection"

# Detect CPU
print_header "CPU Information"

if [ -f /proc/cpuinfo ]; then
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d ':' -f 2 | xargs)
    CPU_VENDOR=$(grep "vendor_id" /proc/cpuinfo | head -n 1 | cut -d ':' -f 2 | xargs)
    CPU_CORES=$(grep -c "^processor" /proc/cpuinfo)
    
    print_info "CPU: $CPU_MODEL"
    print_info "Vendor: $CPU_VENDOR"
    print_info "Cores: $CPU_CORES"
    
    # CPU-specific suggestions
    if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
        print_suggestion "AMD CPU detected - consider enabling AMD-specific optimizations"
        echo "  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;"
    elif [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
        print_suggestion "Intel CPU detected - consider enabling Intel-specific optimizations"
        echo "  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;"
    fi
fi

# Detect GPU
print_header "GPU Information"

GPU_DETECTED=false

# Check for NVIDIA GPU
if command -v lspci &> /dev/null; then
    NVIDIA_GPU=$(lspci | grep -i "vga.*nvidia" || true)
    AMD_GPU=$(lspci | grep -i "vga.*amd\|vga.*radeon" || true)
    INTEL_GPU=$(lspci | grep -i "vga.*intel" || true)
    
    if [ -n "$NVIDIA_GPU" ]; then
        GPU_DETECTED=true
        print_info "NVIDIA GPU detected:"
        echo "  $NVIDIA_GPU"
        echo ""
        print_suggestion "Enable NVIDIA support in your configuration:"
        echo "  hardware.nvidia.enable = true;"
        echo "  hardware.graphics.enable = true;"
        echo ""
        print_warning "You may need to choose between open or proprietary drivers:"
        echo "  hardware.nvidia.open = false;  # Use proprietary drivers (more stable)"
        echo "  hardware.nvidia.open = true;   # Use open-source drivers (newer GPUs)"
    fi
    
    if [ -n "$AMD_GPU" ]; then
        GPU_DETECTED=true
        print_info "AMD GPU detected:"
        echo "  $AMD_GPU"
        echo ""
        print_suggestion "Enable AMD GPU support:"
        echo "  hardware.graphics.enable = true;"
        echo "  # AMD drivers are included by default in the kernel"
    fi
    
    if [ -n "$INTEL_GPU" ]; then
        GPU_DETECTED=true
        print_info "Intel GPU detected:"
        echo "  $INTEL_GPU"
        echo ""
        print_suggestion "Enable Intel GPU support:"
        echo "  hardware.graphics.enable = true;"
        echo "  # Intel drivers are included by default"
    fi
else
    print_warning "lspci command not found - cannot detect GPU"
fi

if [ "$GPU_DETECTED" = false ]; then
    print_warning "No discrete GPU detected (or detection failed)"
    print_suggestion "If you have a GPU, ensure lspci is available"
fi

# Detect Audio Hardware
print_header "Audio Hardware"

if [ -d /proc/asound ]; then
    print_info "Audio hardware detected"
    print_suggestion "Enable audio support:"
    echo "  system.audio.enable = true;"
    echo "  # This will enable PipeWire"
else
    print_warning "No audio hardware detected"
fi

# Detect Network Hardware
print_header "Network Hardware"

if command -v ip &> /dev/null; then
    NETWORK_INTERFACES=$(ip link show | grep -E "^[0-9]+" | cut -d ':' -f 2 | xargs)
    print_info "Network interfaces detected:"
    for iface in $NETWORK_INTERFACES; do
        if [ "$iface" != "lo" ]; then
            echo "  - $iface"
        fi
    done
    echo ""
    print_suggestion "Enable networking:"
    echo "  system.networking.enable = true;"
    echo "  system.networking.hostName = \"your-hostname\";"
fi

# Detect WiFi
if command -v iwconfig &> /dev/null 2>&1 || command -v iw &> /dev/null 2>&1; then
    WIFI_DEVICE=$(iw dev 2>/dev/null | grep Interface | cut -d ' ' -f 2 || true)
    if [ -n "$WIFI_DEVICE" ]; then
        print_info "WiFi device detected: $WIFI_DEVICE"
        print_suggestion "NetworkManager is recommended for WiFi management (enabled by default in networking module)"
    fi
fi

# Detect Bluetooth
print_header "Bluetooth"

if [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
    print_info "Bluetooth hardware detected"
    print_suggestion "Enable Bluetooth support:"
    echo "  hardware.bluetooth.enable = true;"
    echo "  hardware.bluetooth.powerOnBoot = true;"
else
    print_info "No Bluetooth hardware detected"
fi

# Detect Storage
print_header "Storage Devices"

if command -v lsblk &> /dev/null; then
    print_info "Storage devices:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part"
    echo ""
    
    # Check for NVMe
    if lsblk | grep -q nvme; then
        print_suggestion "NVMe storage detected - no special configuration needed"
    fi
    
    # Check for SSD
    if [ -d /sys/block ]; then
        for disk in /sys/block/sd*; do
            if [ -f "$disk/queue/rotational" ]; then
                ROTATIONAL=$(cat "$disk/queue/rotational")
                DISK_NAME=$(basename "$disk")
                if [ "$ROTATIONAL" = "0" ]; then
                    print_info "SSD detected: $DISK_NAME"
                fi
            fi
        done
    fi
fi

# Detect if running in a VM
print_header "Virtualization"

if command -v systemd-detect-virt &> /dev/null; then
    VIRT=$(systemd-detect-virt)
    if [ "$VIRT" != "none" ]; then
        print_info "Running in virtual machine: $VIRT"
        print_suggestion "Consider enabling VM guest tools:"
        case $VIRT in
            kvm|qemu)
                echo "  services.qemuGuest.enable = true;"
                echo "  services.spice-vdagentd.enable = true;"
                ;;
            vmware)
                echo "  virtualisation.vmware.guest.enable = true;"
                ;;
            virtualbox)
                echo "  virtualisation.virtualbox.guest.enable = true;"
                ;;
        esac
    else
        print_info "Running on bare metal"
    fi
fi

# Detect touchpad (for laptops)
print_header "Input Devices"

if [ -d /sys/class/input ]; then
    if grep -r "Touchpad\|TrackPoint" /sys/class/input/*/name 2>/dev/null | grep -q .; then
        print_info "Touchpad detected (laptop)"
        print_suggestion "Enable touchpad support (usually enabled automatically with desktop environments)"
    fi
fi

# Memory information
print_header "Memory"

if [ -f /proc/meminfo ]; then
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{printf "%.1f GB", $2/1024/1024}')
    print_info "Total RAM: $TOTAL_MEM"
fi

# Generate hardware-configuration.nix if needed
print_header "Hardware Configuration"

if command -v nixos-generate-config &> /dev/null; then
    echo "To generate hardware-configuration.nix, run:"
    echo "  sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix"
else
    print_warning "nixos-generate-config not found"
    echo "This command is available on NixOS systems"
fi

# Summary
print_header "Configuration Summary"

echo "Based on the detected hardware, consider enabling these options in your host configuration:"
echo ""

# Build a suggested configuration snippet
cat << 'EOF'
myConfig = {
  # Hardware
EOF

if [ -n "$NVIDIA_GPU" ]; then
    echo "  hardware.nvidia.enable = true;"
fi

if [ "$GPU_DETECTED" = true ]; then
    echo "  hardware.graphics.enable = true;"
fi

cat << 'EOF'

  # Boot
  boot.enable = true;
  boot.useLatestKernel = false;  # Set to true for newer hardware

  # System
  system.enable = true;
  system.networking.enable = true;
  system.networking.hostName = "your-hostname";
  system.security.enable = true;
  system.audio.enable = true;
  system.locale.enable = true;
  system.locale.timeZone = "America/New_York";  # Adjust as needed

  # Development tools (customize as needed)
  development.rust.enable = true;
  development.nodejs.enable = true;
  development.go.enable = true;

  # Shell and editors
  shell.fish.enable = true;
  shell.bash.enable = true;
  shell.zsh.enable = true;
  shell.nushell.enable = true;
  shell.git.enable = true;
  editors.neovim.enable = true;

};

# In hosts/<hostname>/home.nix, enable CLI tools at the Home Manager layer:
myConfig.cliTools = {
  terminals.enableAll = true;
  monitoring.enableAll = true;
  fileTools.enableAll = true;
  formatters.enableAll = true;
  utilities.enableAll = true;
};
EOF

echo ""
print_info "Hardware detection complete!"
print_info "Review the suggestions above and adjust your configuration accordingly."
