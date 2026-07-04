# zcl — run Claude Code against Z.ai's GLM-5.2 Anthropic-compatible API (Windows).
#
# Based on official Z.ai docs: https://docs.z.ai/devpack/tool/claude
#
# Key resolution order:
#   1. `zcl config [KEY]`   — set/replace the stored key (inline or prompt)
#   2. stored config file         — set on a previous run
#   3. $env:ZAI_API_KEY           — used and saved for next time
#   4. interactive prompt         — asks for the key if you haven't included it yet

$ErrorActionPreference = 'Stop'

$Script:Version      = '1.1.0'
$Script:ConfigDir    = Join-Path $env:APPDATA 'zcl'
$Script:ConfigFile   = Join-Path $Script:ConfigDir 'config'

# --- defaults ----------------------------------------------------------------
# Based on official Z.ai docs: https://docs.z.ai/devpack/tool/claude
$Script:DefaultOpusSonnet  = 'glm-5.2[1m]'
$Script:DefaultHaikuModel  = 'glm-4.7'
$Script:DefaultTimeoutMs   = '3000000'
$Script:DefaultAutoCompact = '1000000'

# --- helpers -----------------------------------------------------------------
function Write-Say   { param([string]$Msg) Write-Host $Msg }
function Write-Warn  { param([string]$Msg) Write-Host "WARNING: $Msg" -ForegroundColor Yellow }
function Write-ErrorX { param([string]$Msg) Write-Host "ERROR: $Msg" -ForegroundColor Red; exit 1 }
function Write-DebugX {
  param([string]$Msg)
  if ($env:ZCL_VERBOSE -eq '1') { Write-Host "[DEBUG] $Msg" -ForegroundColor DarkGray }
}

# --- config file I/O ---------------------------------------------------------
function Read-Config {
  param([string]$Key)
  if (-not (Test-Path $Script:ConfigFile)) { return $null }
  foreach ($line in Get-Content $Script:ConfigFile) {
    if ($line -match "^\s*${Key}=(.*)$") { return $Matches[1] }
  }
  return $null
}

function Write-Config {
  param([string]$Key, [string]$Value)
  New-Item -ItemType Directory -Force -Path $Script:ConfigDir | Out-Null
  $lines = @()
  $found = $false
  if (Test-Path $Script:ConfigFile) {
    foreach ($line in Get-Content $Script:ConfigFile) {
      if ($line -match "^\s*${Key}=") {
        $lines += "${Key}=${Value}"
        $found = $true
      } else {
        $lines += $line
      }
    }
  }
  if (-not $found) { $lines += "${Key}=${Value}" }
  Set-Content -Path $Script:ConfigFile -Value $lines -Encoding ASCII
  try {
    $acl = New-Object System.Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
      "$env:USERDOMAIN\$env:USERNAME", 'FullControl', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -Path $Script:ConfigFile -AclObject $acl
  } catch {
    Write-DebugX "Set-Acl failed (non-NTFS drive?): $_"
  }
}

function Save-Key {
  param([string]$Key)
  $Key = $Key.Trim()
  if ([string]::IsNullOrEmpty($Key)) {
    Write-ErrorX 'Refusing to save an empty key.'
  }
  if (-not (Test-KeyFormat $Key)) {
    Write-Warn 'Z.ai keys should follow the format: {API Key ID}.{secret}'
    Write-Warn 'Example: abc123xyz.abcdefghijklmnopqrstuvwxyz'
    Write-Warn 'Saving anyway, but it may not work.'
  }
  Write-Config 'ZAI_API_KEY' $Key
  Write-Say "Key saved to $Script:ConfigFile"
}

function Get-Key {
  return Read-Config 'ZAI_API_KEY'
}

# --- key validation ----------------------------------------------------------
function Test-KeyFormat {
  param([string]$Key)
  # Z.ai keys follow the format: {API Key ID}.{secret}
  return ($Key -match '^[a-zA-Z0-9]+\.[a-zA-Z0-9]+$')
}

function Test-KeyApi {
  param([string]$Key)
  Write-Say 'Verifying API key...'
  try {
    $resp = Invoke-WebRequest -Uri 'https://api.z.ai/api/paas/v4/models' `
      -Headers @{ Authorization = "Bearer $Key" } `
      -Method Get `
      -TimeoutSec 10 `
      -SkipHttpErrorCheck `
      -ErrorAction SilentlyContinue
    if ($resp.StatusCode -eq 200) {
      Write-Say '[v] API key is valid.'
      return $true
    } elseif ($resp.StatusCode -eq 401) {
      Write-Warn '[x] API key is invalid or expired (HTTP 401).'
      return $false
    } elseif ($resp.StatusCode -eq 403) {
      Write-Warn '[x] API key lacks permissions (HTTP 403).'
      return $false
    } else {
      Write-Warn "Unexpected response (HTTP $($resp.StatusCode)). Key may still work."
      return $true
    }
  } catch {
    Write-Warn 'Could not reach Z.ai API (network error).'
    return $true
  }
}

# --- interactive setup -------------------------------------------------------
function Invoke-Setup {
  Write-Say ''
  Write-Say '+------------------------------------------+'
  Write-Say '|  zcl - first-time setup                  |'
  Write-Say '+------------------------------------------+'
  Write-Say ''
  Write-Say "Claude Code will run against Z.ai's GLM-5.2 API."
  Write-Say 'You only need to enter your key once.'
  Write-Say ''
  Write-Say '1. Buat akun di https://z.ai'
  Write-Say '2. Setelah login, buka https://z.ai/manage-apikey/apikey-list'
  Write-Say ''
  Write-Say 'The API key format is: {API Key ID}.{secret}'
  Write-Say 'Example: a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6.AbCdEfGhIjKlMnOpQrStUvWxYz112233'
  Write-Say ''
  Write-Say 'WARNING: Keep your key secure. Z.ai auto-revokes publicly exposed keys.'
  Write-Say ''
  for ($i = 0; $i -lt 3; $i++) {
    $secure = Read-Host -AsSecureString 'Z.ai API key'
    $bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $key    = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    $key = $key.Trim()
    if ($key) {
      if (-not (Test-KeyFormat $key)) {
        Write-Warn 'Key should be in format: {API Key ID}.{secret} (e.g. abc123.xyz789)'
      }
      Save-Key $key
      Write-Say ''
      Write-Say 'Key saved. Verifying...'
      Test-KeyApi $key | Out-Null
      return
    }
    Write-Say "Key can't be empty."
  }
  Write-ErrorX 'Aborting after 3 empty attempts.'
}

# --- help --------------------------------------------------------------------
function Show-Help {
@'
zcl — run Claude Code against Z.ai's GLM-5.2 Anthropic-compatible API.

USAGE
  zcl [FLAGS] [--] [ARGUMENTS...]

FLAGS
  --help, help       Show this help message
  --version          Show version number
  --dry-run          Print what would be executed, without running Claude Code
  --verbose          Print debug information during execution
  --safe             Run WITHOUT --dangerously-skip-permissions (more prompts)

SUBCOMMANDS
  zcl config [KEY]       Set or change the stored API key
  zcl change-key [KEY]   Alias for config
  zcl reset              Delete the stored API key
  zcl update             Update to the latest version
  zcl verify             Verify the stored API key against Z.ai API
  zcl show-config        Print current configuration (key masked)
  zcl model              Interactively select the Z.ai model to use
  zcl doctor             Run diagnostic checks
  zcl clean              Clear local Claude Code cache/memory
  zcl alias [NAME]       Create a shell shortcut (e.g. zcl alias c)

KEY RESOLUTION ORDER
  1. zcl config <KEY>
  2. Stored config file (%APPDATA%\zcl\config)
  3. ZAI_API_KEY environment variable (auto-saved on use)
  4. Interactive prompt

ENVIRONMENT VARIABLES
  ZAI_API_KEY                   Z.ai API key (saved automatically on first use)
  ZCL_SAFE=1                    Same as --safe
  ZCL_VERBOSE=1                 Same as --verbose
  ZCL_OPUS_SONNET_MODEL         Opus/Sonnet model (default: glm-5.2[1m])
  ZCL_HAIKU_MODEL               Haiku model (default: glm-4.7)
  ZCL_TIMEOUT_MS                API timeout in ms (default: 3000000 = 50 min)
  ZCL_AUTO_COMPACT              Auto-compact window (default: 1000000)

MODEL INFO
  Available Z.ai Models:
    glm-5.2[1m], glm-5.2, glm-5.1, glm-5
    glm-5-turbo, glm-4.7, glm-4.6, glm-4.5
    glm-4-32b-0414-128k, GLM-4.7-Flash

  Use /effort inside Claude Code to set reasoning effort.
  GLM-5.2 maps: low/medium/high -> high, xhigh/max/ultracode -> max

CONFIG FILE
  Path:  %APPDATA%\zcl\config
  Format: KEY=VALUE (one per line)

EXAMPLES
  zcl                              # First run: enter key, then start
  zcl "refactor this module"       # Pass a prompt to Claude Code
  zcl --safe "rm -rf ./build"      # Run with permission prompts enabled
  zcl --dry-run --verbose          # Preview what will be set
  zcl config <your-key>            # Set key without interactive prompt
  zcl verify                       # Check if your stored key works
  zcl show-config                  # See current settings
'@
  exit 0
}

# --- show config -------------------------------------------------------------
function Show-Config {
  $key = Get-Key
  $savedSafe = if ($val = Read-Config 'ZCL_SAFE') { $val } else { '0' }

  Write-Host "Config file : $Script:ConfigFile"
  Write-Host "Config dir  : $Script:ConfigDir"
  Write-Host '---'
  if ($key) { Write-Host "API key     : (stored, $($key.Length) chars)" } else { Write-Host 'API key     : (not set)' }
  Write-Host "Safe mode   : $(if ($env:ZCL_SAFE) { $env:ZCL_SAFE } else { $savedSafe })"
  Write-Host '---'
  Write-Host 'Model overrides (from config or env):'
  $opusSonnet = if ($env:ZCL_OPUS_SONNET_MODEL) { $env:ZCL_OPUS_SONNET_MODEL } else { $v = Read-Config 'ZCL_OPUS_SONNET_MODEL'; if ($v) { $v } else { $Script:DefaultOpusSonnet } }
  $haiku      = if ($env:ZCL_HAIKU_MODEL)        { $env:ZCL_HAIKU_MODEL }        else { $v = Read-Config 'ZCL_HAIKU_MODEL';        if ($v) { $v } else { $Script:DefaultHaikuModel } }
  $timeoutMs  = if ($env:ZCL_TIMEOUT_MS)         { $env:ZCL_TIMEOUT_MS }         else { $v = Read-Config 'ZCL_TIMEOUT_MS';         if ($v) { $v } else { $Script:DefaultTimeoutMs } }

  Write-Host "  OPUS/SONNET  : $opusSonnet"
  Write-Host "  HAIKU        : $haiku"
  Write-Host "  TIMEOUT_MS   : $timeoutMs"
  exit 0
}

# --- dry run -----------------------------------------------------------------
function Invoke-DryRun {
  param([array]$RemainingArgs)
  $key        = Get-Key
  $safeMode   = if ($env:ZCL_SAFE)                { $env:ZCL_SAFE }                else { $v = Read-Config 'ZCL_SAFE';                if ($v) { $v } else { '0' } }
  $opusSonnet = if ($env:ZCL_OPUS_SONNET_MODEL)   { $env:ZCL_OPUS_SONNET_MODEL }   else { $v = Read-Config 'ZCL_OPUS_SONNET_MODEL';   if ($v) { $v } else { $Script:DefaultOpusSonnet } }
  $haiku      = if ($env:ZCL_HAIKU_MODEL)          { $env:ZCL_HAIKU_MODEL }          else { $v = Read-Config 'ZCL_HAIKU_MODEL';          if ($v) { $v } else { $Script:DefaultHaikuModel } }
  $timeoutMs  = if ($env:ZCL_TIMEOUT_MS)           { $env:ZCL_TIMEOUT_MS }           else { $v = Read-Config 'ZCL_TIMEOUT_MS';           if ($v) { $v } else { $Script:DefaultTimeoutMs } }
  $autoCompact = if ($env:ZCL_AUTO_COMPACT)         { $env:ZCL_AUTO_COMPACT }         else { $v = Read-Config 'ZCL_AUTO_COMPACT';         if ($v) { $v } else { $Script:DefaultAutoCompact } }

  Write-Host '═══════════════════════════════════════════════'
  Write-Host '  zcl dry-run'
  Write-Host '═══════════════════════════════════════════════'
  Write-Host ''
  Write-Host 'Would set these environment variables:'
  Write-Host ''
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_BASE_URL', 'https://api.z.ai/api/anthropic')
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_AUTH_TOKEN', $(if ($key) { "(hidden, $($key.Length) chars)" } else { '(not set)' }))
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_DEFAULT_OPUS_MODEL', $opusSonnet)
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_DEFAULT_SONNET_MODEL', $opusSonnet)
  Write-Host ('  {0,-36} {1}' -f 'ANTHROPIC_DEFAULT_HAIKU_MODEL', $haiku)
  Write-Host ('  {0,-36} {1}' -f 'API_TIMEOUT_MS', $timeoutMs)
  Write-Host ('  {0,-36} {1}' -f 'CLAUDE_CODE_AUTO_COMPACT_WINDOW', $autoCompact)
  Write-Host ''
  Write-Host 'Note: Use /effort inside Claude Code to set reasoning effort.'
  Write-Host '      GLM-5.2 maps: low/med/high->high, xhigh/max/ultracode->max'
  Write-Host ''
  if ($safeMode -eq '1') {
    Write-Host "Would run: claude $($RemainingArgs -join ' ')"
  } else {
    Write-Host "Would run: claude --dangerously-skip-permissions $($RemainingArgs -join ' ')"
  }
  Write-Host ''
  if ($safeMode -ne '1') {
    Write-Host '⚠  --dangerously-skip-permissions is ENABLED (use --safe to disable)'
  } else {
    Write-Host '[v]  Safe mode: tools will require per-action approval'
  }
  exit 0
}

# --- subcommand handler ------------------------------------------------------
function Invoke-Subcommand {
  param([string]$Cmd, [array]$SubArgs)

  if ($Cmd -match '^(config|--config|set-key|--set-key|change|--change|change-key|--change-key)$') {
    if ($SubArgs.Count -ge 1) { Save-Key $SubArgs[0] } else { Invoke-Setup }
    Write-Say "Done. Run 'zcl' to start."
    exit 0
  } elseif ($Cmd -match '^(reset|--reset)$') {
    if (Test-Path $Script:ConfigFile) {
      Remove-Item $Script:ConfigFile -Force
      Write-Say "Stored key removed ($Script:ConfigFile)."
    } else {
      Write-Say 'No stored key to remove.'
    }
    exit 0
  } elseif ($Cmd -match '^(model|models|--model|--models)$') {
    Write-Say "--- Z.ai Models ---"
    Write-Say "1. glm-5.2[1m]  (Flagship, 1M context)"
    Write-Say "2. glm-5.2      (Standard 1M context)"
    Write-Say "3. glm-5.1      (Previous generation)"
    Write-Say "4. glm-5        (Standard Gen 5)"
    Write-Say "5. glm-5-turbo  (High speed)"
    Write-Say "6. glm-4.7      (Fast & cheap, 200K)"
    Write-Say "7. glm-4.6"
    Write-Say "8. glm-4.5"
    Write-Say "9. glm-4-32b-0414-128k"
    Write-Say "10. GLM-4.7-Flash (Free, ultra fast)"
    $choice = Read-Host "Select a model (1-10) [leave blank to cancel]"
    $model = switch ($choice.Trim()) {
      '1' { 'glm-5.2[1m]' }
      '2' { 'glm-5.2' }
      '3' { 'glm-5.1' }
      '4' { 'glm-5' }
      '5' { 'glm-5-turbo' }
      '6' { 'glm-4.7' }
      '7' { 'glm-4.6' }
      '8' { 'glm-4.5' }
      '9' { 'glm-4-32b-0414-128k' }
      '10' { 'GLM-4.7-Flash' }
      ''  { Write-Say "Cancelled."; exit 0 }
      default { Write-ErrorX "Invalid choice."; exit 1 }
    }
    Write-Config 'ZCL_OPUS_SONNET_MODEL' $model
    Write-Say "Default model has been set to: $model"
    exit 0
  } elseif ($Cmd -match '^(update|--update|upgrade|--upgrade)$') {
    Write-Say 'Updating zcl to the latest version...'
    irm "https://raw.githubusercontent.com/Muhira007/z-ai-claude/main/install.ps1?v=$([guid]::NewGuid().ToString().Substring(0, 8))" | iex
    exit 0
  } elseif ($Cmd -match '^(verify|--verify)$') {
    $key = Get-Key
    if (-not $key) { Write-ErrorX "No stored key. Run 'zcl config' first." }
    Write-Say "Stored key: $($key.Substring(0, [Math]::Min(5, $key.Length)))...$($key.Substring($key.Length - [Math]::Min(4, $key.Length))) ($($key.Length) chars)"
    if (Test-KeyFormat $key) {
      Write-Say 'Format:  [v]'
    } else {
      Write-Warn 'Format:  [x] (unusual format)'
    }
    Test-KeyApi $key | Out-Null
    exit 0
  } elseif ($Cmd -match '^(doctor)$') {
    Write-Say "--- Zcl Doctor ---"
    $healthy = $true
    
    # Node.js check
    if (Get-Command node -ErrorAction SilentlyContinue) {
      $nodeVer = (node -v).Trim()
      Write-Say "[v] Node.js installed ($nodeVer)"
    } else {
      Write-Warn "[x] Node.js not found. Claude Code requires Node.js."
      $healthy = $false
    }
    
    # npm check
    if (Get-Command npm -ErrorAction SilentlyContinue) {
      $npmVer = (npm -v).Trim()
      Write-Say "[v] npm installed ($npmVer)"
    } else {
      Write-Warn "[x] npm not found."
      $healthy = $false
    }
    
    # claude check
    if (Get-Command claude -ErrorAction SilentlyContinue) {
      $claudeVer = (claude --version).Trim()
      Write-Say "[v] Claude Code installed ($claudeVer)"
    } else {
      Write-Warn "[x] Claude Code not found. Will prompt for auto-install on launch."
      $healthy = $false
    }
    
    # API Key
    $key = Get-Key
    if ($key) {
      Write-Say "[v] API Key is configured."
      if (Test-KeyApi $key) {
        Write-Say "[v] API Key can reach Z.ai servers successfully."
      } else {
        Write-Warn "[x] API Key failed validation."
        $healthy = $false
      }
    } else {
      Write-Warn "[x] No API Key set. Run 'zcl config'."
      $healthy = $false
    }
    
    if ($healthy) {
      Write-Say "`nSystem is fully ready to use Zcl!"
    } else {
      Write-Warn "`nSome checks failed. Please fix the warnings above."
    }
    exit 0
  } elseif ($Cmd -match '^(clean)$') {
    Write-Say "Clearing Claude Code memory/cache..."
    $localClaude = Join-Path (Get-Location) ".claude"
    if (Test-Path $localClaude) {
      Remove-Item -Recurse -Force $localClaude
      Write-Say "[v] Removed local project memory ($localClaude)"
    } else {
      Write-Say "[v] No local project memory found."
    }
    exit 0
  } elseif ($Cmd -match '^(alias)$') {
    $aliasName = 'c'
    if ($SubArgs.Count -gt 0) { $aliasName = $SubArgs[0] }
    if (-not (Test-Path $PROFILE)) {
      New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    $aliasCmd = "Set-Alias $aliasName zcl"
    Add-Content -Path $PROFILE -Value "`n# Added by zcl`n$aliasCmd"
    Write-Say "[v] Alias '$aliasName' for 'zcl' has been added to your PowerShell profile ($PROFILE)."
    Write-Say "Restart your terminal or run . '$PROFILE' to use it."
    exit 0
  } elseif ($Cmd -match '^(show-config|--show-config|show|--show)$') {
    Show-Config
  } elseif ($Cmd -match '^(help|--help|-h)$') {
    Show-Help
  }
}

# ============================================================================
# MAIN
# ============================================================================

$dryRun      = $false
$passthrough = [System.Collections.ArrayList]::new()
$i           = 0

while ($i -lt $args.Count) {
  switch ($args[$i]) {
    '--help'    { Show-Help }
    'help'      { Show-Help }
    '-h'        { Show-Help }
    '--version' { Write-Host "zcl v$Script:Version"; exit 0 }
    '--dry-run' { $dryRun = $true; $i++ }
    '--verbose' { $env:ZCL_VERBOSE = '1'; $i++ }
    '--safe'    { $env:ZCL_SAFE = '1'; $i++ }
    '--'        { $i++; for (; $i -lt $args.Count; $i++) { $passthrough.Add($args[$i]) | Out-Null }; break }
    default {
      if ($args[$i] -match '^(config|--config|set-key|--set-key|change|--change|change-key|--change-key|reset|--reset|model|models|--model|--models|update|--update|upgrade|--upgrade|verify|--verify|doctor|clean|alias|show-config|--show-config|show|--show)$') {
        $subArgs = @()
        for ($j = $i + 1; $j -lt $args.Count; $j++) { $subArgs += $args[$j] }
        Invoke-Subcommand -Cmd $args[$i] -SubArgs $subArgs
      }
      $passthrough.Add($args[$i]) | Out-Null
      $i++
    }
  }
}

Write-DebugX "zcl v$Script:Version starting"

# --- check for updates (async-like) ------------------------------------------
function Check-For-Updates {
  try {
    $lastCheckFile = Join-Path $Script:ConfigDir "last_update_check"
    $check = $true
    if (Test-Path $lastCheckFile) {
      $lastCheck = [datetime](Get-Content $lastCheckFile)
      if ((Get-Date) -lt $lastCheck.AddDays(1)) { $check = $false }
    }
    if ($check) {
      $resp = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Muhira007/z-ai-claude/main/VERSION" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
      if ($resp.StatusCode -eq 200) {
        $remoteVer = $resp.Content.Trim()
        if ($remoteVer -ne $Script:Version -and $remoteVer -match '^\d+\.\d+\.\d+') {
          Write-Host "`n🚀 New version of Zcl is available ($remoteVer)! Run 'zcl update' to install.`n" -ForegroundColor Yellow
        }
      }
      (Get-Date).ToString("o") | Out-File -FilePath $lastCheckFile -Encoding ascii
    }
  } catch {}
}
Check-For-Updates

Write-DebugX "CONFIG_FILE=$Script:ConfigFile"
Write-DebugX "DRY_RUN=$dryRun"
Write-DebugX "ZCL_SAFE=$(if ($env:ZCL_SAFE) { $env:ZCL_SAFE } else { '0' })"
Write-DebugX "ZCL_VERBOSE=$(if ($env:ZCL_VERBOSE) { $env:ZCL_VERBOSE } else { '0' })"

# --- resolve the key ---------------------------------------------------------
$key = Get-Key
Write-DebugX "Key from config: $(if ($key) { "found ($($key.Length) chars)" } else { 'not found' })"

if (-not $key -and $env:ZAI_API_KEY) {
  $key = $env:ZAI_API_KEY.Trim()
  Write-Say 'Using ZAI_API_KEY from environment; saving for next time.'
  try {
    Save-Key $key
  } catch {
    Write-Warn "Could not save key to $Script:ConfigFile (disk full or permission issue?)."
    Write-Warn 'Key will only be used for this session.'
  }
}

if (-not $key) {
  Invoke-Setup
  $key = Get-Key
}

if (-not $key) {
  Write-ErrorX "No API key available. Run 'zcl config' to set one."
}

Write-DebugX "Key resolved ($($key.Length) chars)"

# --- resolve model overrides -------------------------------------------------
$opusSonnet = if ($env:ZCL_OPUS_SONNET_MODEL) { $env:ZCL_OPUS_SONNET_MODEL } else { $v = Read-Config 'ZCL_OPUS_SONNET_MODEL'; if ($v) { $v } else { $Script:DefaultOpusSonnet } }
$haiku      = if ($env:ZCL_HAIKU_MODEL)        { $env:ZCL_HAIKU_MODEL }        else { $v = Read-Config 'ZCL_HAIKU_MODEL';        if ($v) { $v } else { $Script:DefaultHaikuModel } }
$timeoutMs  = if ($env:ZCL_TIMEOUT_MS)         { $env:ZCL_TIMEOUT_MS }         else { $v = Read-Config 'ZCL_TIMEOUT_MS';         if ($v) { $v } else { $Script:DefaultTimeoutMs } }
$autoCompact = if ($env:ZCL_AUTO_COMPACT)       { $env:ZCL_AUTO_COMPACT }       else { $v = Read-Config 'ZCL_AUTO_COMPACT';       if ($v) { $v } else { $Script:DefaultAutoCompact } }
$safeMode    = if ($env:ZCL_SAFE)               { $env:ZCL_SAFE }               else { $v = Read-Config 'ZCL_SAFE';               if ($v) { $v } else { '0' } }

Write-DebugX "OPUS_SONNET=$opusSonnet"
Write-DebugX "HAIKU_MODEL=$haiku"
Write-DebugX "TIMEOUT_MS=$timeoutMs"
Write-DebugX "AUTO_COMPACT=$autoCompact"
Write-DebugX "SAFE_MODE=$safeMode"

# --- dry-run early exit ------------------------------------------------------
if ($dryRun) {
  Invoke-DryRun -RemainingArgs $passthrough.ToArray()
}

# --- launch ------------------------------------------------------------------
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-Warn "claude CLI not found on PATH."
  $ans = Read-Host "Would you like Zcl to automatically install Claude Code via npm? [Y/n]"
  if ($ans -notmatch "^[nN]") {
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
      Write-ErrorX "npm is not installed! Please install Node.js first."
    }
    Write-Say "Installing @anthropic-ai/claude-code globally..."
    npm install -g @anthropic-ai/claude-code
    if ($LASTEXITCODE -ne 0) { Write-ErrorX "Installation failed." }
    Write-Say "[v] Claude Code installed successfully."
  } else {
    Write-ErrorX "Install Claude Code manually: https://docs.claude.com/en/docs/claude-code"
  }
}

# Env vars based on official Z.ai docs: https://docs.z.ai/devpack/tool/claude
$env:ANTHROPIC_BASE_URL             = 'https://api.z.ai/api/anthropic'
$env:ANTHROPIC_AUTH_TOKEN           = $key
$env:ANTHROPIC_DEFAULT_OPUS_MODEL   = $opusSonnet
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $opusSonnet
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL  = $haiku
$env:API_TIMEOUT_MS                 = $timeoutMs
$env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = $autoCompact

Write-DebugX 'Environment variables set. Launching claude...'
Write-DebugX "ANTHROPIC_BASE_URL=$env:ANTHROPIC_BASE_URL"

if ($safeMode -eq '1') {
  Write-Say 'Running in safe mode (permission prompts enabled).'
  & claude @passthrough
} else {
  & claude --dangerously-skip-permissions @passthrough
}
exit $LASTEXITCODE
