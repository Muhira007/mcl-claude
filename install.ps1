# mcl — run Claude Code against MiMo's MiMo-5.2 Anthropic-compatible API (Windows).
#
# Key resolution order:
#   1. `mcl config [KEY]`   — set/replace the stored key (inline or prompt)
#   2. stored config file         — set on a previous run
#   3. $env:MCL_API_KEY           — used and saved for next time
#   4. interactive prompt         — asks for the key if you haven't included it yet

param(
    [string]$Version = "main",
    [string]$Dest = "$env:LOCALAPPDATA\Programs\mcl"
)

$ErrorActionPreference = 'Stop'

$RepoUrl = "https://raw.githubusercontent.com/Muhira007/z-ai-claude/$Version"
$CmdName = "mcl"

Write-Host "Installing $CmdName ($Version) to $Dest ..."

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Download the PowerShell script (with cache-buster to bypass GitHub CDN cache)
$cacheBuster = [guid]::NewGuid().ToString().Substring(0, 8)
$scriptUrl = "$RepoUrl/$CmdName.ps1?t=$cacheBuster"
$scriptPath = Join-Path $Dest "$CmdName.ps1"
Write-Host "Downloading $scriptUrl ..."
Invoke-WebRequest -Uri $scriptUrl -OutFile $scriptPath

# Create a batch wrapper so it's callable as 'mcl' from cmd/terminal
$batchPath = Join-Path $Dest "$CmdName.cmd"
@"
@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" %*
"@ | Set-Content -Path $batchPath -Encoding ASCII

Write-Host "Installed: $scriptPath"
Write-Host "Installed: $batchPath"

# Check and update PATH automatically
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if ($userPath -split ';' -notcontains $Dest) {
    Write-Host ""
    Write-Host "Adding $Dest to your User PATH..."
    
    $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $Dest } else { "$userPath;$Dest" }
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
    
    # Update current session PATH so it can be used immediately
    $env:PATH = "$env:PATH;$Dest"
    
    Write-Host "Successfully added to PATH!"
    Write-Host "You can now run '$CmdName' right away."
} else {
    Write-Host ""
    Write-Host "Ready. Run: $CmdName"
}
