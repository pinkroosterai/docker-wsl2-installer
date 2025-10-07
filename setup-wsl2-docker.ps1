#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Prepares Windows for Docker Engine in WSL2
.DESCRIPTION
    Installs/updates WSL2, installs Ubuntu, and prepares environment for Docker installation
.NOTES
    Must be run as Administrator
#>

# Color output functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Success" = "Green"
        "Error" = "Red"
        "Warning" = "Yellow"
        "Info" = "Cyan"
        "Header" = "Magenta"
    }
    
    Write-Host $Message -ForegroundColor $colors[$Type]
}

function Write-Header {
    param([string]$Text)
    Write-Host "`n" -NoNewline
    Write-Host ("="*80) -ForegroundColor Magenta
    Write-Host " $Text" -ForegroundColor Magenta
    Write-Host ("="*80) -ForegroundColor Magenta
}

# Check Windows version
function Test-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    $build = $version.Build
    
    Write-ColorOutput "Checking Windows version..." "Info"
    
    if ($version.Major -lt 10) {
        Write-ColorOutput "Error: Windows 10 or later required" "Error"
        return $false
    }
    
    if ($version.Major -eq 10 -and $build -lt 19043) {
        Write-ColorOutput "Error: Windows 10 build 19043 or later required. Current build: $build" "Error"
        Write-ColorOutput "Please update Windows before continuing" "Warning"
        return $false
    }
    
    Write-ColorOutput "✓ Windows version check passed (Build $build)" "Success"
    return $true
}

# Check if WSL is installed
function Test-WSLInstalled {
    try {
        $wslStatus = wsl --status 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Install or update WSL
function Install-WSL {
    Write-Header "WSL2 Installation/Update"
    
    $wslInstalled = Test-WSLInstalled
    
    if (-not $wslInstalled) {
        Write-ColorOutput "WSL not detected. Installing WSL..." "Info"
        Write-ColorOutput "This will require a system restart..." "Warning"
        
        try {
            wsl --install --no-distribution
            Write-ColorOutput "✓ WSL installation initiated" "Success"
            Write-ColorOutput "`nIMPORTANT: Please restart your computer, then run this script again." "Warning"
            Write-Host "`nPress any key to exit..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 0
        }
        catch {
            Write-ColorOutput "Error installing WSL: $_" "Error"
            return $false
        }
    }
    else {
        Write-ColorOutput "✓ WSL is installed" "Success"
        
        # Update WSL
        Write-ColorOutput "Updating WSL to latest version..." "Info"
        try {
            wsl --update
            Write-ColorOutput "✓ WSL updated successfully" "Success"
        }
        catch {
            Write-ColorOutput "Warning: Could not update WSL (may already be latest version)" "Warning"
        }
    }
    
    return $true
}

# Set WSL2 as default
function Set-WSL2Default {
    Write-ColorOutput "Setting WSL2 as default version..." "Info"
    try {
        wsl --set-default-version 2
        Write-ColorOutput "✓ WSL2 set as default" "Success"
        return $true
    }
    catch {
        Write-ColorOutput "Error setting WSL2 as default: $_" "Error"
        return $false
    }
}

# Check if Ubuntu is installed
function Test-UbuntuInstalled {
    $distros = wsl --list --quiet
    return $distros -match "Ubuntu"
}

# Install Ubuntu
function Install-Ubuntu {
    Write-Header "Ubuntu Distribution Installation"
    
    if (Test-UbuntuInstalled) {
        Write-ColorOutput "✓ Ubuntu is already installed" "Success"
        
        # List installed distributions
        Write-ColorOutput "`nInstalled WSL distributions:" "Info"
        wsl --list --verbose
        
        return $true
    }
    
    Write-ColorOutput "Installing Ubuntu 24.04..." "Info"
    Write-ColorOutput "This may take several minutes..." "Warning"
    
    try {
        wsl --install -d Ubuntu-24.04
        
        Write-ColorOutput "`n✓ Ubuntu installation initiated" "Success"
        Write-ColorOutput "`nUbuntu will now launch for initial setup." "Info"
        Write-ColorOutput "Please create a username and password when prompted." "Warning"
        
        # Wait a moment for installation to complete
        Start-Sleep -Seconds 3
        
        return $true
    }
    catch {
        Write-ColorOutput "Error installing Ubuntu: $_" "Error"
        return $false
    }
}

# Set Ubuntu as default distribution
function Set-UbuntuDefault {
    Write-ColorOutput "`nSetting Ubuntu as default WSL distribution..." "Info"
    
    $ubuntuDistro = (wsl --list --quiet | Where-Object { $_ -match "Ubuntu" } | Select-Object -First 1).Trim()
    
    if ($ubuntuDistro) {
        try {
            wsl --set-default $ubuntuDistro
            Write-ColorOutput "✓ Ubuntu set as default distribution" "Success"
            return $true
        }
        catch {
            Write-ColorOutput "Warning: Could not set Ubuntu as default" "Warning"
            return $true  # Non-critical error
        }
    }
    else {
        Write-ColorOutput "Warning: Could not find Ubuntu distribution" "Warning"
        return $false
    }
}

# Main script execution
function Main {
    Write-Header "Docker Engine in WSL2 - Windows Setup Script"
    Write-ColorOutput "This script prepares Windows for Docker Engine installation in WSL2`n" "Info"
    
    # Check Windows version
    if (-not (Test-WindowsVersion)) {
        exit 1
    }
    
    # Install/Update WSL
    if (-not (Install-WSL)) {
        Write-ColorOutput "`nSetup failed at WSL installation step" "Error"
        exit 1
    }
    
    # Set WSL2 as default
    if (-not (Set-WSL2Default)) {
        Write-ColorOutput "`nSetup failed at WSL2 configuration step" "Error"
        exit 1
    }
    
    # Install Ubuntu
    if (-not (Install-Ubuntu)) {
        Write-ColorOutput "`nSetup failed at Ubuntu installation step" "Error"
        exit 1
    }
    
    # Set Ubuntu as default
    Set-UbuntuDefault | Out-Null
    
    # Final instructions
    Write-Header "Windows Setup Complete!"
    
    Write-ColorOutput "`n✓ WSL2 is installed and updated" "Success"
    Write-ColorOutput "✓ Ubuntu is installed and configured" "Success"
    Write-ColorOutput "`nNext Steps:" "Header"
    Write-ColorOutput "1. Open Ubuntu from the Start Menu or run: wsl" "Info"
    Write-ColorOutput "2. Download the bash installation script inside Ubuntu:" "Info"
    Write-ColorOutput "   curl -fsSL https://your-host/install-docker-wsl2.sh -o install-docker-wsl2.sh" "Info"
    Write-ColorOutput "   (or create the install-docker-wsl2.sh file manually)" "Info"
    Write-ColorOutput "3. Make it executable: chmod +x install-docker-wsl2.sh" "Info"
    Write-ColorOutput "4. Run it: ./install-docker-wsl2.sh" "Info"
    
    Write-ColorOutput "`nAlternatively, copy the bash script content and run it directly in Ubuntu." "Info"
    
    Write-Host "`n"
}

# Run main function
Main