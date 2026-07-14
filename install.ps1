# mcl installer — anti-cache PowerShell edition
# Usage:
#   irm https://raw.githubusercontent.com/Muhira007/mcl-claude/main/install.ps1?v=... | iex
#   Or download and run: .\install.ps1
#
# Parameters:
#   -Version "main"     — branch/tag to install (default: main)
#   -Dest "C:\..."      — custom install directory
#   -Force              — skip all confirmation prompts
#
param(
    [string]$Version = "main",
    [string]$Dest = "$env:LOCALAPPDATA\Programs\mcl",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Anti-cache: when invoked via `irm ... | iex`, the pipeline itself might be
# stale.  If the script body is empty or shorter than expected, alert the user.
# ---------------------------------------------------------------------------
if ($MyInvocation.MyCommand.ScriptContents -and $MyInvocation.MyCommand.ScriptContents.Length -lt 100) {
    Write-Host "ERROR: Downloaded script appears truncated (cached stub?)." -ForegroundColor Red
    Write-Host "Clear the PowerShell web cache and try again:"
    Write-Host "  Remove-Item -Force `$env:LOCALAPPDATA\Microsoft\Windows\INetCache\* -Recurse -ErrorAction SilentlyContinue"
    Write-Host "  ipconfig /flushdns"
    exit 1
}

$RepoRaw  = "https://raw.githubusercontent.com/Muhira007/mcl-claude/$Version"
$CmdName  = "mcl"
$psVersion = $PSVersionTable.PSVersion

Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║  mcl installer v2 (anti-cache)          ║"
Write-Host "╚══════════════════════════════════════════╝"
Write-Host ""
Write-Host "  Version : $Version"
Write-Host "  Dest    : $Dest"
Write-Host "  PS      : $psVersion"
Write-Host ""

# --- helpers ---
function Write-Step($msg) { Write-Host "  » $msg" }
function Write-OK($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

# --- anti-cache download function ------------------------------------------
<#
.SYNOPSIS
  Downloads a file with aggressive cache-busting.

.DESCRIPTION
  Combines multiple techniques to ensure a FRESH download every time:
  1. Triple cache-buster query params (timestamp + ticks + random GUID)
  2. HTTP headers: Cache-Control & Pragma set to no-cache/no-store
  3. .NET WebClient with RequestCachePolicy = NoCacheNoStore (bypasses IE cache)
  4. Removes any existing local file before downloading
  5. Built-in retry logic (compatible with PS 5.1 and 7+)
#>
function Invoke-FreshDownload {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$MaxRetries = 3
    )

    # Remove stale file first — prevents "file already exists / locked" issues
    if (Test-Path $OutFile) {
        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
    }

    # Triple cache-buster: timestamp (s) + ticks (100ns) + random GUID fragment
    $ts    = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $ticks = [DateTime]::UtcNow.Ticks
    $rnd   = [guid]::NewGuid().ToString().Substring(0, 8)

    $separator = if ($Url -match '\?') { '&' } else { '?' }
    $freshUrl  = "${Url}${separator}ts=${ts}&ticks=${ticks}&r=${rnd}"

    Write-Step "Downloading..."

    # Hide the progress bar — speeds up the request significantly
    $prevProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $attempt = 0
    $success = $false

    while ($attempt -lt $MaxRetries -and -not $success) {
        $attempt++
        if ($attempt -gt 1) {
            Write-Host "    Retry $attempt/$MaxRetries..." -ForegroundColor Yellow
            Start-Sleep -Seconds (2 * $attempt)
        }

        try {
            # ---- Primary: .NET WebClient with disabled cache ----
            # WebClient + NoCacheNoStore bypasses the WinINET/IE cache entirely,
            # which `Invoke-WebRequest` can't do on PowerShell 5.1.
            $wc = New-Object System.Net.WebClient

            # Anti-cache HTTP headers
            $wc.Headers.Add('Cache-Control', 'no-cache, no-store, must-revalidate')
            $wc.Headers.Add('Pragma', 'no-cache')
            $wc.Headers.Add('X-Force-Fresh', 'true')

            # This is the key: disable the local cache at the .NET level
            $wc.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy(
                [System.Net.Cache.RequestCacheLevel]::NoCacheNoStore
            )

            $wc.DownloadFile($freshUrl, $OutFile)
            $wc.Dispose()

            # Verify the downloaded file is non-empty
            if ((Test-Path $OutFile) -and (Get-Item $OutFile).Length -gt 0) {
                $size = (Get-Item $OutFile).Length
                Write-OK "Downloaded ($size bytes)"
                $success = $true
            }
            else {
                throw "Downloaded file is empty (likely cached 304 response)"
            }
        }
        catch {
            Write-Err "Attempt $attempt failed: $_"

            # Fallback: Invoke-WebRequest with explicit headers (works better on PS 7+)
            if ($attempt -eq $MaxRetries -or $_.Exception.Message -match 'cache|304|empty') {
                try {
                    Write-Host "    Trying Invoke-WebRequest fallback..." -ForegroundColor Yellow
                    $headers = @{
                        'Cache-Control' = 'no-cache, no-store, must-revalidate, max-age=0'
                        'Pragma'         = 'no-cache'
                        'Accept'         = 'text/plain, */*'
                    }
                    Invoke-WebRequest -Uri $freshUrl -OutFile $OutFile `
                        -Headers $headers -UseBasicParsing -TimeoutSec 30

                    if ((Test-Path $OutFile) -and (Get-Item $OutFile).Length -gt 0) {
                        $size = (Get-Item $OutFile).Length
                        Write-OK "Downloaded via fallback ($size bytes)"
                        $success = $true
                    }
                }
                catch {
                    # Will be handled below
                }
            }
        }
    }

    $ProgressPreference = $prevProgress

    if (-not $success) {
        Write-Err "Download failed after $MaxRetries attempts."
        Write-Host ""
        Write-Host "  TROUBLESHOOTING:" -ForegroundColor Cyan
        Write-Host "  1. ipconfig /flushdns           ← clear DNS cache"
        Write-Host "  2. Clear-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name 'ProxyServer' -ErrorAction SilentlyContinue"
        Write-Host "  3. Delete: %LOCALAPPDATA%\Microsoft\Windows\INetCache\*"
        Write-Host "  4. Try a different network / VPN"
        Write-Host "  5. Manual download: https://github.com/Muhira007/mcl-claude"
        return $false
    }

    return $true
}

# --- install ---------------------------------------------------------------

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Download mcl.ps1
$ps1Url  = "$RepoRaw/$CmdName.ps1"
$ps1Path = Join-Path $Dest "$CmdName.ps1"

if (-not (Invoke-FreshDownload -Url $ps1Url -OutFile $ps1Path)) {
    exit 1
}

# --- create .cmd wrapper (so it's callable as 'mcl' from cmd/terminal) -----
$batchPath = Join-Path $Dest "$CmdName.cmd"
@"
@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1Path" %*
"@ | Set-Content -Path $batchPath -Encoding ASCII
Write-OK "Created wrapper: $batchPath"

# --- create direct PowerShell alias script (mcl without .ps1 extension) ----
$directPath = Join-Path $Dest "$CmdName"
@"
#!/usr/bin/env pwsh
# Direct launcher for mcl (called from PATH as 'mcl' without extension)
& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "$ps1Path" @args
"@ | Set-Content -Path $directPath -Encoding ASCII
Write-OK "Created direct launcher: $directPath"

# --- PATH setup ------------------------------------------------------------
$machinePath = [Environment]::GetEnvironmentVariable('PATH', 'Machine')
$userPath    = [Environment]::GetEnvironmentVariable('PATH', 'User')
$currentPath = "$env:PATH"

$needsUserPath   = ($userPath -split ';') -notcontains $Dest
$needsMachinePath = ($machinePath -split ';') -notcontains $Dest

if ($needsUserPath -and $needsMachinePath) {
    Write-Host ""
    if (-not $Force) {
        Write-Host "  Add $Dest to your User PATH? [Y/n]" -ForegroundColor Yellow
        $answer = Read-Host
        if ($answer -eq 'n' -or $answer -eq 'N') {
            Write-Host "  Skipped. You'll need to add it manually or use full path."
            Write-Host "  Run: $ps1Path"
            exit 0
        }
    }

    Write-Step "Adding to User PATH..."
    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $Dest } else { "$userPath;$Dest" }
    [Environment]::SetEnvironmentVariable('PATH', $newUserPath, 'User')

    # Also update current session so it works immediately
    $env:PATH = "$env:PATH;$Dest"
    Write-OK "Added to PATH (current + permanent)"
}
else {
    Write-OK "Already on PATH"
}

# --- done ------------------------------------------------------------------
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗"
Write-Host "║  Installation complete!                 ║"
Write-Host "╠══════════════════════════════════════════╣"
Write-Host "║  Run:  mcl                              ║"
Write-Host "║  Help: mcl --help                       ║"
Write-Host "╚══════════════════════════════════════════╝"
