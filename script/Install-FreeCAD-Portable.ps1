<#
.SYNOPSIS
Downloads and installs the latest stable or weekly portable release of FreeCAD.
#>

$ErrorActionPreference = "Stop"

function Write-Log {
    param(
        [string]$Message, 
        [string]$Type = "INFO",
        [switch]$LogOnly
    )
    
    if (-not $LogOnly) {
        if ($Type -eq "ERROR") {
            Write-Host $Message -ForegroundColor Red
        } elseif ($Type -eq "SUCCESS") {
            Write-Host $Message -ForegroundColor Green
        } else {
            Write-Host $Message
        }
    }
    
    if ($null -ne $global:installLog -and (Test-Path (Split-Path $global:installLog))) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logLine = "[$timestamp] [$Type] $Message"
        Add-Content -Path $global:installLog -Value $logLine -Encoding UTF8
    }
}

function Exit-Script {
    param([int]$ExitCode = 0)
    Write-Host ""
    if ($null -ne $global:installLog -and (Test-Path (Split-Path $global:installLog))) {
        Write-Host "A detailed log file is available at:" -ForegroundColor Cyan
        Write-Host $global:installLog -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "Press any key to close this window..."
    
    # Flush the input buffer to discard any leftover keystrokes (e.g. the Enter key from earlier)
    while ($Host.UI.RawUI.KeyAvailable) {
        $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp") | Out-Null
    }
    
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit $ExitCode
}

# Load Windows Forms to show Folder Dialog
Add-Type -AssemblyName System.Windows.Forms

# Show folder browser dialog (using modern OpenFileDialog hack)
$folderBrowser = New-Object System.Windows.Forms.OpenFileDialog
$folderBrowser.Title = "Please select the folder where the portable FreeCAD installation should be created."
$folderBrowser.ValidateNames = $false
$folderBrowser.CheckFileExists = $false
$folderBrowser.CheckPathExists = $true
$folderBrowser.FileName = "Folder Selection"
$folderBrowser.Filter = "Folders|*.none"

# Create a topmost dummy form so the dialog appears in the foreground
$dummyForm = New-Object System.Windows.Forms.Form
$dummyForm.TopMost = $true
$dummyForm.TopLevel = $true

$validFolderSelected = $false
while (-not $validFolderSelected) {
    $dialogResult = $folderBrowser.ShowDialog($dummyForm)
    
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $installDir = Split-Path $folderBrowser.FileName
        
        # Check for existing portable FreeCAD installation markers
        $hasFreecadExe  = Test-Path -Path (Join-Path $installDir "freecad\FreeCAD.exe")
        $hasFreecadBin  = Test-Path -Path (Join-Path $installDir "freecad\bin") -PathType Container
        
        if ($hasFreecadExe -or $hasFreecadBin) {
            # Try to extract version
            $packagesFile = Join-Path $installDir "freecad\packages.txt"
            $version = "UNKNOWN"
            if (Test-Path -Path $packagesFile) {
                $versionMatch = Select-String -Path $packagesFile -Pattern "^freecad\s+([0-9\.]+)" -ErrorAction SilentlyContinue
                if ($versionMatch) {
                    $version = $versionMatch.Matches[0].Groups[1].Value
                }
            }
            
            $msgResult = [System.Windows.Forms.MessageBox]::Show(
                $dummyForm,
                "An existing FreeCAD installation (Version: $version) was found in the selected folder.`n`nDo you want to delete and overwrite this installation?`nSelect 'No' to choose a different folder.",
                "FreeCAD Installation Detected",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            
            if ($msgResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                $validFolderSelected = $true
            }
        } else {
            # No installation detected, proceed normally
            $validFolderSelected = $true
        }
    } else {
        Write-Host "Installation cancelled by user (No target folder selected)."
        Exit-Script -ExitCode 0
    }
}

$global:installLog = Join-Path $installDir "Install-FreeCAD.log"
# Create or clear the log file
Set-Content -Path $global:installLog -Value "--- FreeCAD Portable Installation Log ---" -Encoding UTF8

Write-Log "Selected installation folder: $installDir"
Write-Log ""

Write-Log "Enforcing TLS 1.2 for GitHub API..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Log "Fetching release information from GitHub..."
try {
    $releases = Invoke-RestMethod -Uri 'https://api.github.com/repos/FreeCAD/FreeCAD/releases' -UserAgent "FreeCAD_Windows_Portable_Deployer/1.0.0"
    Write-Log "Successfully fetched release data." -Type "SUCCESS"
} catch {
    Write-Log "Error fetching release data from GitHub: $_" -Type "ERROR"
    Exit-Script -ExitCode 1
}

$stableRelease = $releases | Where-Object { $_.prerelease -eq $false } | Select-Object -First 1
$weeklyRelease = $releases | Where-Object { $_.prerelease -eq $true -and $_.tag_name -like '*weekly*' } | Select-Object -First 1

Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "FreeCAD Version Selection"
$form.Size = New-Object System.Drawing.Size(400,200)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

$label = New-Object System.Windows.Forms.Label
$label.Text = "Please select the FreeCAD version to install:"
$label.Location = New-Object System.Drawing.Point(15,20)
$label.AutoSize = $true
$form.Controls.Add($label)

$radioStable = New-Object System.Windows.Forms.RadioButton
$radioStable.Text = "Stable Release: $($stableRelease.name)"
$radioStable.Location = New-Object System.Drawing.Point(20,50)
$radioStable.AutoSize = $true
$radioStable.Checked = $true
$form.Controls.Add($radioStable)

$radioWeekly = New-Object System.Windows.Forms.RadioButton
$radioWeekly.Text = "Weekly Build: $($weeklyRelease.name)"
$radioWeekly.Location = New-Object System.Drawing.Point(20,80)
$radioWeekly.AutoSize = $true
$form.Controls.Add($radioWeekly)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Location = New-Object System.Drawing.Point(100,120)
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Location = New-Object System.Drawing.Point(200,120)
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelButton)

$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton

$form.StartPosition = "CenterScreen"
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    if ($radioStable.Checked) {
        $selectedRelease = $stableRelease
    } else {
        $selectedRelease = $weeklyRelease
    }
} else {
    Write-Log "Installation cancelled." -Type "ERROR"
    Exit-Script -ExitCode 1
}

Write-Log "User selected version: $($selectedRelease.name)"

# Find the 7z asset and its SHA256 file for Windows
$asset = $selectedRelease.assets | Where-Object { $_.name -match '(?i)(win|windows).*?(x64|x86_64).*?\.7z$' -and $_.name -notmatch '(?i)pdb' } | Select-Object -First 1
$hashAsset = $selectedRelease.assets | Where-Object { $_.name -eq "$($asset.name)-SHA256.txt" } | Select-Object -First 1

if (-not $asset) {
    Write-Log "Could not find a .7z file for the selected release." -Type "ERROR"
    Exit-Script -ExitCode 1
}
if (-not $hashAsset) {
    Write-Log "Could not find the SHA256 hash file for verification." -Type "ERROR"
    Exit-Script -ExitCode 1
}

$downloadUrl = $asset.browser_download_url
$fileName = $asset.name
# Download the archive to the selected installation directory
$archivePath = Join-Path $installDir $fileName

$hashDownloadUrl = $hashAsset.browser_download_url
$hashFileName = $hashAsset.name
$hashFilePath = Join-Path $installDir $hashFileName

Write-Log "--- DOWNLOAD INFORMATION ---"
Write-Log "File: $fileName"
Write-Log "Hash File: $hashFileName"
Write-Log "Target path: $archivePath"
Write-Log "URL: $downloadUrl"
Write-Log "Hash URL: $hashDownloadUrl"
Write-Log "------------------------------"
Write-Log "Download starting now..."

try {
    $filesToDownload = @(
        @{ Url = $downloadUrl; Path = $archivePath; Name = "FreeCAD Archive" },
        @{ Url = $hashDownloadUrl; Path = $hashFilePath; Name = "Hash File" }
    )

    foreach ($file in $filesToDownload) {
        $request = [System.Net.HttpWebRequest]::Create($file.Url)
        $request.UserAgent = "FreeCAD-Portable-Installer/0.5.9"
        $response = $request.GetResponse()
        $totalBytes = $response.ContentLength
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.FileStream($file.Path, [System.IO.FileMode]::Create)
        $buffer = New-Object byte[] 65536
        $downloaded = 0
        
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $reader.Write($buffer, 0, $read)
            $downloaded += $read
            if ($totalBytes -gt 0) {
                $percent = [math]::Round(($downloaded / $totalBytes) * 100)
                Write-Progress -Activity "Downloading $($file.Name)" -Status "$percent% Complete" -PercentComplete $percent
            }
        }
        $reader.Close()
        $stream.Close()
        $response.Close()
        Write-Progress -Activity "Downloading $($file.Name)" -Completed
    }
    
    Write-Log "Download completed successfully." -Type "SUCCESS"
} catch {
    Write-Log "Error downloading FreeCAD archive or hash file: $_" -Type "ERROR"
    Exit-Script -ExitCode 1
}

Write-Log "Verifying file integrity (SHA256 Hash)..."
try {
    $expectedHashLine = Get-Content $hashFilePath -Raw
    $expectedHash = $expectedHashLine.Trim().Substring(0, 64).ToUpper()
    Write-Log "-> Expected Hash (from GitHub): $expectedHash"
    
    Write-Log "-> Computing local hash for downloaded archive. This may take a moment..."
    $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToUpper()
    Write-Log "-> Actual Hash (computed locally): $actualHash"
    
    if ($actualHash -eq $expectedHash) {
        Write-Log "Hash verification passed! Both values match perfectly." -Type "SUCCESS"
    } else {
        Write-Log "Hash verification failed! Expected $expectedHash but got $actualHash" -Type "ERROR"
        Exit-Script -ExitCode 1
    }
} catch {
    Write-Log "Error during hash verification: $_" -Type "ERROR"
    Exit-Script -ExitCode 1
}

# Setup 7z
$7zPath = Join-Path $PSScriptRoot "7zr.exe"
if (-not (Test-Path $7zPath)) {
    Write-Log "Bundled extraction tool (7zr.exe) not found. Searching for system 7-Zip..."
    $sys7z64 = Join-Path $env:ProgramFiles "7-Zip\7z.exe"
    $sys7z32 = Join-Path ${env:ProgramFiles(x86)} "7-Zip\7z.exe"
    
    if (Get-Command "7z.exe" -ErrorAction SilentlyContinue) {
        $7zPath = "7z.exe"
        Write-Log "System 7-Zip (7z.exe) found in PATH. Using it as fallback." -Type "SUCCESS"
    } elseif (Test-Path $sys7z64) {
        $7zPath = $sys7z64
        Write-Log "System 7-Zip (7z.exe) found in Program Files. Using it as fallback." -Type "SUCCESS"
    } elseif (Test-Path $sys7z32) {
        $7zPath = $sys7z32
        Write-Log "System 7-Zip (7z.exe) found in Program Files (x86). Using it as fallback." -Type "SUCCESS"
    } else {
        Write-Log "Error: Neither bundled 7zr.exe nor system 7z.exe were found." -Type "ERROR"
        Write-Log "Please download '7zr.exe' from 'https://www.7-zip.org/a/7zr.exe' and place it in the following directory:" -Type "ERROR"
        Write-Log "-> $PSScriptRoot" -Type "ERROR"
        Exit-Script -ExitCode 1
    }
} else {
    Write-Log "Found bundled extraction tool (7zr.exe)."
}

$extractPath = Join-Path $installDir "freecad"
if (Test-Path $extractPath) {
    Write-Log "Deleting existing 'freecad' folder..."
    Remove-Item -Path $extractPath -Recurse -Force
}

# Create target dir
New-Item -ItemType Directory -Path $extractPath | Out-Null

Write-Log "Extracting archive to: $extractPath"
Write-Host "Please wait, this may take a few minutes. Extraction progress will be shown below:"
Write-Log ""

try {
    # Run 7z with -bso0 to hide normal output (file list/headers) and -bsp1 to show only progress output
    $7zProcess = Start-Process -FilePath $7zPath -ArgumentList "x `"$archivePath`" -o`"$extractPath`" -y -bso0 -bsp1" -Wait -NoNewWindow -PassThru
    if ($7zProcess.ExitCode -ne 0) {
        throw "7z exit code was $($7zProcess.ExitCode)"
    }
    Write-Log "Extraction completed successfully." -Type "SUCCESS"
} catch {
    Write-Log "Error extracting archive: $_" -Type "ERROR"
    Exit-Script -ExitCode 1
}

Write-Log "Cleaning up temporary files..."
try {
    Remove-Item -Path $archivePath -Force
    Remove-Item -Path $hashFilePath -Force
    Write-Log "Cleanup successful." -Type "SUCCESS"
} catch {
    Write-Log "Error cleaning up files: $_" -Type "ERROR"
}

# We might need to move contents up one level if extraction created an inner folder
$subdirs = Get-ChildItem -Path $extractPath -Directory
if ($subdirs.Count -eq 1 -and (Test-Path (Join-Path $subdirs[0].FullName "bin\FreeCAD.exe"))) {
    Write-Log "Adjusting folder structure..."
    try {
        $innerPath = $subdirs[0].FullName
        Get-ChildItem -Path $innerPath -Force | Move-Item -Destination $extractPath -Force
        Remove-Item -Path $innerPath -Force
        Write-Log "Folder structure adjusted successfully." -Type "SUCCESS"
    } catch {
        Write-Log "Error adjusting folder structure: $_" -Type "ERROR"
    }
}

# Create FreeCad_portable.bat in the target base directory
Write-Log "Creating launcher script..."
$batContent = @"
@echo off
chcp 65001 > nul
:: determining base folder
:: (location of .bat file)
set `"BASEDIR=%~dp0`"
set `"BASEDIR=%BASEDIR:~0,-1%`"

:: defining paths
set `"FREECAD_DIR=%BASEDIR%\freecad`"
set `"CONFIG_DIR=%BASEDIR%\userconfig`"
set `"DATA_DIR=%BASEDIR%\userdata`"

:: creating folders if not exist	
if not exist `"%CONFIG_DIR%`" mkdir `"%CONFIG_DIR%`"
if not exist `"%DATA_DIR%`" mkdir `"%DATA_DIR%`"

:: redirecting userdata
:: (for macros and userdata)
set `"FREECAD_USER_DATA=%DATA_DIR%`"
set `"FREECAD_USER_HOME=%DATA_DIR%`"
set `"APPDATA=%DATA_DIR%`"

:: starting and isolating config files
:: (placing system.cfg and user.cfg in 'userconfig')
start `"`" `"%FREECAD_DIR%\bin\FreeCAD.exe`" -u `"%CONFIG_DIR%\user.cfg`" -s `"%CONFIG_DIR%\system.cfg`"
"@

try {
    $batPath = Join-Path $installDir "FreeCad_portable.bat"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($batPath, $batContent, $utf8NoBom)
    Write-Log "Launcher script created." -Type "SUCCESS"
} catch {
    Write-Log "Error creating launcher script: $_" -Type "ERROR"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Log "Installation completed successfully!" -Type "SUCCESS"
Write-Host ""

# Log plain text to file silently
Write-Log "FreeCAD Portable has been installed in folder: $installDir" -LogOnly
Write-Log "To start FreeCAD, run the following script: $batPath" -LogOnly

# Output visually separated text to console only
Write-Host "-> FreeCAD Portable has been installed in folder:" -ForegroundColor Yellow
Write-Host "   $installDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "-> To start FreeCAD, run the following script:" -ForegroundColor Yellow
Write-Host "   $batPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan

Exit-Script -ExitCode 0
