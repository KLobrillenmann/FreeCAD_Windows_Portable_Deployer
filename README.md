# FreeCAD_Windows_Portable_Deployer
A Powershell script for Windows to download, extract and prepare FeeCAD as a truly portable instance.

# FreeCAD Portable Deployer

![PowerShell](https://img.shields.io/badge/PowerShell-%235391FE.svg?style=flat&logo=powershell&logoColor=white)
![FreeCAD](https://img.shields.io/badge/FreeCAD-Portable-blue)

A robust, PowerShell-based deployment script to download and set up the latest Stable or Weekly release of [FreeCAD](https://www.freecad.org/) as a fully portable environment on Windows.

## About the Project
This tool automates the entire FreeCAD deployment process. It fetches the required archives directly via the GitHub API, verifies file integrity using a SHA256 hash, extracts the files, and creates a startup batch script that strictly isolates FreeCAD. All configurations and user data remain within the installation directory (sandboxing). The system does not modify the Windows registry and leaves no traces in `%APPDATA%`.

## Features
* **Automated Retrieval:** Dynamically fetches the latest release assets (Stable & Weekly) directly from the FreeCAD GitHub repository.
* **Secure:** Automatic integrity check of the download via SHA256 matching prior to installation.
* **Strict Sandboxing:** Generates an isolated launcher that redirects `user.cfg`, `system.cfg`, macros, and application data to the target folder.
* **Flexible:** Optional use of a bundled extractor (`7zr.exe`) or automatic fallback to a system-wide 7-Zip installation.
* **User-Friendly:** Graphical folder and version selection during installation, plus a convenient `Install.bat` wrapper for quick startup.

## Requirements
* Windows (x64)
* Windows PowerShell 5.1 or newer
* Internet connection for GitHub API access

## Installation & Usage

1. Download the repository as a ZIP file or clone it via Git:
   ```bash
   git clone https://github.com/YourUsername/YourRepoName.git
   ```
2. Ensure the file structure is intact (the `Install.bat` in the root directory and the PowerShell script in the `script` folder).
3. Run the `Install.bat` file by double-clicking it.
4. Follow the dialogs to select the target directory and the desired FreeCAD version.
5. After successful installation, FreeCAD can be started directly from the target directory using the newly generated `FreeCad_portable.bat`.

## Folder Structure After Installation
The script creates the following self-contained structure in the selected target directory:
```text
[Selected Installation Directory]\
├── freecad\                 # The extracted FreeCAD program files
├── userconfig\              # Isolated system.cfg and user.cfg
├── userdata\                # Isolated %APPDATA% replacement (for addons, macros, etc.)
├── FreeCad_portable.bat     # The isolated launcher for FreeCAD
└── Install-FreeCAD.log      # Detailed installation log
```

## Troubleshooting
If the installation fails, check the `Install-FreeCAD.log` in the installation folder. All steps, HTTP requests, and hash comparisons are documented there with timestamps.

## License
This project is free and unencumbered software released into the public domain. For more information, see the [LICENSE](LICENSE) file or visit [unlicense.org](https://unlicense.org).
