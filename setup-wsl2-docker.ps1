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
    
    Write-ColorOutput "Windows version check passed (Build $build)" "Success"
    return $true
}

# Check if system restart is pending
function Test-PendingRestart {
    $restartPending = $false

    # Check Component Based Servicing
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
        $restartPending = $true
    }

    # Check Windows Update
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $restartPending = $true
    }

    # Check pending file rename operations
    $fileRenameKey = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    if ($fileRenameKey -and $fileRenameKey.PendingFileRenameOperations) {
        $restartPending = $true
    }

    return $restartPending
}

# Check if WSL is installed
function Test-WSLInstalled {
    try {
        $null = wsl --status 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# Install or update WSL
function Install-WSL {
    Write-Header "WSL2 Installation/Update"

    # Check if restart is already pending from previous installation attempt
    if (Test-PendingRestart) {
        Write-ColorOutput "System restart is pending from previous installation" "Warning"
        Write-ColorOutput "WSL installation requires a restart to complete." "Error"
        Write-ColorOutput "`nPlease restart your computer, then run this script again." "Warning"
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 0
    }

    $wslInstalled = Test-WSLInstalled

    if (-not $wslInstalled) {
        Write-ColorOutput "WSL not detected. Installing WSL..." "Info"
        Write-ColorOutput "This will require a system restart..." "Warning"

        try {
            wsl --install --no-distribution

            if ($LASTEXITCODE -ne 0) {
                Write-ColorOutput "Error: WSL installation command failed" "Error"
                return $false
            }

            Write-ColorOutput "WSL installation initiated" "Success"

            # Give Windows a moment to register the pending restart
            Start-Sleep -Seconds 2

            # Verify restart is now pending
            if (Test-PendingRestart) {
                Write-ColorOutput "`nRestart requirement confirmed by system" "Info"
            }

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
        Write-ColorOutput "WSL is installed" "Success"

        # Update WSL
        Write-ColorOutput "Updating WSL to latest version..." "Info"
        try {
            wsl --update
            Write-ColorOutput "WSL updated successfully" "Success"
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
        Write-ColorOutput "WSL2 set as default" "Success"
        return $true
    }
    catch {
        Write-ColorOutput "Error setting WSL2 as default: $_" "Error"
        return $false
    }
}

# Check if Ubuntu is installed
function Test-UbuntuInstalled {
    $ubuntuDistro = wsl --list --quiet | ForEach-Object { $_.Trim() -replace '\x00','' } | Where-Object { $_ -match "Ubuntu-24.04" } | Select-Object -First 1

    return $ubuntuDistro
}

# Install Ubuntu
function Install-Ubuntu {
    Write-Header "Ubuntu Distribution Installation"
    
    if (Test-UbuntuInstalled) {
        Write-ColorOutput "Ubuntu is already installed" "Success"
        
        # List installed distributions
        Write-ColorOutput "`nInstalled WSL distributions:" "Info"
        wsl --list --verbose
        
        return $true
    }
    
    Write-ColorOutput "Installing Ubuntu 24.04..." "Info"
    Write-ColorOutput "This may take several minutes..." "Warning"
    
    try {
        wsl --install -d Ubuntu-24.04

        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Error: Ubuntu installation command failed" "Error"
            return $false
        }

        Write-ColorOutput "`nUbuntu installation initiated" "Success"
        Write-ColorOutput "`nUbuntu will now launch for initial setup." "Info"
        Write-ColorOutput "Please complete the setup (create username and password) in the Ubuntu window." "Warning"
        Write-ColorOutput "Waiting for installation to complete..." "Info"
    }
    catch {
        Write-ColorOutput "Error installing Ubuntu: $_" "Error"
        return $false
    }
}

# Set Ubuntu as default distribution
function Set-UbuntuDefault {
    Write-ColorOutput "`nSetting Ubuntu as default WSL distribution..." "Info"

    $ubuntuDistro = wsl --list --quiet | ForEach-Object { $_.Trim() -replace '\x00','' } | Where-Object { $_ -match "Ubuntu-24.04" } | Select-Object -First 1

    if ($ubuntuDistro) {
        $ubuntuDistro = $ubuntuDistro.Trim()
        try {
            wsl --set-default $ubuntuDistro
            Write-ColorOutput "Ubuntu set as default distribution" "Success"
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
    
    Write-ColorOutput "`nWSL2 is installed and updated" "Success"
    Write-ColorOutput "Ubuntu is installed and configured" "Success"
    Write-ColorOutput "`nNext Steps:" "Header"
    Write-ColorOutput "1. Open Ubuntu from the Start Menu or run: wsl" "Info"
    Write-ColorOutput "2. Make the bash script executable: chmod +x install-docker-wsl2.sh" "Info"
    Write-ColorOutput "3. Run it: ./install-docker-wsl2.sh" "Info"
    
    
    Write-Host "`n"
}

# Run main function
Main