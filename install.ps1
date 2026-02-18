#Requires -Version 5.1
<#
.SYNOPSIS
    Jupyter Auto-Installer — One-liner setup for Python + Jupyter Notebook
.DESCRIPTION
    Automatically installs Python, pip, and Jupyter Notebook with customizable packages.
    Can be run directly from GitHub:
    irm https://raw.githubusercontent.com/sitaurs/jupyter-autoinstall/main/install.ps1 | iex
.NOTES
    Author: sitaurs
    License: MIT
#>

# ============================================================
#  CONFIG
# ============================================================

$DEFAULT_PYTHON_VERSION = "3.13.7"
$DEFAULT_INSTALL_DIR    = "C:\Python313"
$DEFAULT_PACKAGES       = @("notebook")
$REPO_RAW_URL           = "https://raw.githubusercontent.com/sitaurs/jupyter-autoinstall/main"

# ============================================================
#  HELPERS
# ============================================================

function Write-Step {
    param([string]$Icon, [string]$Message, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "  $Icon " -NoNewline -ForegroundColor $Color
    Write-Host $Message
}

function Write-SubStep {
    param([string]$Message, [string]$Color = "DarkGray")
    Write-Host "     $Message" -ForegroundColor $Color
}

function Write-Banner {
    $banner = @"

    ╔══════════════════════════════════════════════════╗
    ║                                                  ║
    ║   🐍  Jupyter Auto-Installer                     ║
    ║   ──────────────────────────                     ║
    ║   Python + Jupyter Notebook in one command       ║
    ║                                                  ║
    ╚══════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Yellow
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================
#  LOAD CONFIG (from local file or remote)
# ============================================================

function Get-InstallConfig {
    $configPath = Join-Path $PSScriptRoot "config.json"
    $config = $null

    # Try local config first
    if (Test-Path $configPath) {
        Write-SubStep "Loading config from local config.json"
        try {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
        } catch {
            Write-SubStep "Warning: Could not parse config.json, using defaults" "Yellow"
        }
    } else {
        # Try remote config
        Write-SubStep "Loading config from GitHub..."
        try {
            $remoteConfig = Invoke-RestMethod -Uri "$REPO_RAW_URL/config.json" -ErrorAction Stop
            $config = $remoteConfig
        } catch {
            Write-SubStep "Using default configuration" "Yellow"
        }
    }

    # Build final config with defaults
    $result = @{
        PythonVersion  = if ($config -and $config.python_version)  { $config.python_version }  else { $DEFAULT_PYTHON_VERSION }
        InstallDir     = if ($config -and $config.install_dir)     { $config.install_dir }     else { $DEFAULT_INSTALL_DIR }
        Packages       = if ($config -and $config.packages)        { $config.packages }        else { $DEFAULT_PACKAGES }
        CreateShortcut = if ($config -and $null -ne $config.create_shortcut) { $config.create_shortcut } else { $true }
        AutoLaunch     = if ($config -and $null -ne $config.auto_launch)     { $config.auto_launch }     else { $true }
    }

    return $result
}

# ============================================================
#  STEP 1: CHECK / INSTALL PYTHON
# ============================================================

function Install-Python {
    param($Config)

    $pythonExe = Join-Path $Config.InstallDir "python.exe"
    $version   = $Config.PythonVersion

    # Check if Python already exists and works
    if (Test-Path $pythonExe) {
        try {
            $currentVersion = & $pythonExe --version 2>&1
            # Test if standard library works
            $libTest = & $pythonExe -c "import os, sys; print('OK')" 2>&1
            if ($libTest -eq "OK") {
                Write-Step "✅" "Python already installed: $currentVersion" "Green"
                return $pythonExe
            }
        } catch {}
        Write-Step "⚠️" "Python found but broken, reinstalling..." "Yellow"
    }

    Write-Step "📥" "Installing Python $version..."

    # Download installer
    $installerUrl  = "https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
    $installerPath = Join-Path $env:TEMP "python-$version-amd64.exe"

    Write-SubStep "Downloading from python.org..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
    } catch {
        Write-Step "❌" "Download failed: $_" "Red"
        exit 1
    }

    Write-SubStep "Running installer (this may take a minute)..."

    # Install with all components
    $installArgs = @(
        "InstallAllUsers=1"
        "PrependPath=1"
        "Include_pip=1"
        "Include_test=0"
        "TargetDir=$($Config.InstallDir)"
        "/passive"
    )

    $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Step "❌" "Python installation failed (exit code: $($process.ExitCode))" "Red"
        exit 1
    }

    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Verify
    if (Test-Path $pythonExe) {
        $ver = & $pythonExe --version 2>&1
        Write-Step "✅" "Python installed: $ver" "Green"
    } else {
        Write-Step "❌" "Python installation verification failed" "Red"
        exit 1
    }

    # Cleanup installer
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    return $pythonExe
}

# ============================================================
#  STEP 2: ENSURE PIP
# ============================================================

function Install-Pip {
    param([string]$PythonExe)

    Write-Step "📦" "Checking pip..."

    $pipCheck = & $PythonExe -m pip --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-SubStep "pip already installed: $pipCheck"
        return
    }

    Write-SubStep "Installing pip..."
    & $PythonExe -m ensurepip --upgrade 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        # Fallback: get-pip.py
        Write-SubStep "Trying get-pip.py fallback..."
        $getPipPath = Join-Path $env:TEMP "get-pip.py"
        Invoke-WebRequest -Uri "https://bootstrap.pypa.io/get-pip.py" -OutFile $getPipPath -UseBasicParsing
        & $PythonExe $getPipPath 2>&1 | Out-Null
        Remove-Item $getPipPath -Force -ErrorAction SilentlyContinue
    }

    # Upgrade pip
    & $PythonExe -m pip install --upgrade pip 2>&1 | Out-Null

    $pipVer = & $PythonExe -m pip --version 2>&1
    Write-Step "✅" "pip ready: $pipVer" "Green"
}

# ============================================================
#  STEP 3: INSTALL PACKAGES
# ============================================================

function Install-Packages {
    param([string]$PythonExe, [array]$Packages)

    if (-not $Packages -or $Packages.Count -eq 0) {
        Write-Step "⏭️" "No packages to install" "Yellow"
        return
    }

    Write-Step "📚" "Installing packages..."

    $total = $Packages.Count
    $current = 0

    foreach ($pkg in $Packages) {
        $current++
        $pct = [math]::Round(($current / $total) * 100)

        # Check if already installed
        $check = & $PythonExe -m pip show $pkg 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-SubStep "[$current/$total] $pkg — already installed ✓"
            continue
        }

        Write-SubStep "[$current/$total] Installing $pkg... ($pct%)"
        & $PythonExe -m pip install $pkg --quiet 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0) {
            Write-SubStep "Warning: Failed to install $pkg" "Yellow"
        }
    }

    Write-Step "✅" "All packages installed!" "Green"
}

# ============================================================
#  STEP 4: CREATE DESKTOP SHORTCUT
# ============================================================

function New-JupyterShortcut {
    param([string]$PythonExe)

    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "Jupyter Notebook.lnk"

    if (Test-Path $shortcutPath) {
        Write-SubStep "Desktop shortcut already exists"
        return
    }

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $PythonExe
        $shortcut.Arguments = "-m notebook"
        $shortcut.WorkingDirectory = [System.Environment]::GetFolderPath("UserProfile")
        $shortcut.Description = "Launch Jupyter Notebook"
        $shortcut.IconLocation = "$PythonExe,0"
        $shortcut.Save()

        Write-Step "🖥️" "Desktop shortcut created: Jupyter Notebook" "Green"
    } catch {
        Write-SubStep "Could not create shortcut: $_" "Yellow"
    }
}

# ============================================================
#  STEP 5: LAUNCH JUPYTER
# ============================================================

function Start-Jupyter {
    param([string]$PythonExe)

    Write-Step "🚀" "Launching Jupyter Notebook..." "Magenta"
    Write-Host ""
    Write-Host "  ────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Jupyter will open in your default browser." -ForegroundColor White
    Write-Host "  Press Ctrl+C in this terminal to stop it." -ForegroundColor DarkGray
    Write-Host "  ────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    & $PythonExe -m notebook
}

# ============================================================
#  MAIN
# ============================================================

function Main {
    Clear-Host
    Write-Banner

    # Check admin
    if (-not (Test-AdminRights)) {
        Write-Step "⚠️" "Running without admin. Install may require elevated privileges." "Yellow"
        Write-SubStep "Right-click PowerShell → Run as Administrator if install fails."
    }

    # Load config
    Write-Step "⚙️" "Loading configuration..."
    $config = Get-InstallConfig
    Write-SubStep "Python version : $($config.PythonVersion)"
    Write-SubStep "Install dir    : $($config.InstallDir)"
    Write-SubStep "Packages       : $($config.Packages -join ', ')"

    # Step 1: Python
    $pythonExe = Install-Python -Config $config

    # Step 2: pip
    Install-Pip -PythonExe $pythonExe

    # Step 3: Packages (Jupyter + extras)
    Install-Packages -PythonExe $pythonExe -Packages $config.Packages

    # Step 4: Desktop Shortcut
    if ($config.CreateShortcut) {
        New-JupyterShortcut -PythonExe $pythonExe
    }

    # Summary
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║  ✅  Installation Complete!               ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""

    # Step 5: Auto-launch
    if ($config.AutoLaunch) {
        Start-Jupyter -PythonExe $pythonExe
    } else {
        Write-Step "💡" "To start Jupyter Notebook, run:" "Cyan"
        Write-Host "     python -m notebook" -ForegroundColor White
        Write-Host ""
    }
}

# Run
Main
