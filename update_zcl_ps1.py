import re
import sys

with open('zcl.ps1', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update Version
code = re.sub(r"\$Script:Version\s*=\s*'1\.0\.0'", "$Script:Version      = '1.1.0'", code)

# 2. Add doctor, clean, alias to SUBCOMMANDS help menu
help_addition = """  zcl model              Interactively select the Z.ai model to use
  zcl doctor             Run diagnostic checks
  zcl clean              Clear local Claude Code cache/memory
  zcl alias [NAME]       Create a shell shortcut (e.g. zcl alias c)"""
code = code.replace("  zcl model              Interactively select the Z.ai model to use", help_addition)

# 3. Add doctor, clean, alias to Subcommand Regex
regex_old = r"'^\(config\|--config\|set-key\|--set-key\|change\|--change\|change-key\|--change-key\|reset\|--reset\|model\|models\|--model\|--models\|update\|--update\|upgrade\|--upgrade\|verify\|--verify\|show-config\|--show-config\|show\|--show\)\$'"
regex_new = r"'^(config|--config|set-key|--set-key|change|--change|change-key|--change-key|reset|--reset|model|models|--model|--models|update|--update|upgrade|--upgrade|verify|--verify|show-config|--show-config|show|--show|doctor|clean|alias)$'"
code = code.replace(regex_old, regex_new)

# 4. Implement doctor, clean, alias commands in Invoke-Subcommand
subcommand_block = """    '^(verify|--verify)$' {
      $key = Get-Key
      if (-not $key) { Write-ErrorX "No stored key. Run 'zcl config' first." }
      Write-Say "Stored key: $($key.Substring(0, [Math]::Min(5, $key.Length)))...$($key.Substring($key.Length - [Math]::Min(4, $key.Length))) ($($key.Length) chars)"
      if (Test-KeyFormat $key) {
        Write-Say 'Format:  ✓'
      } else {
        Write-Warn 'Format:  ✗ (unusual format)'
      }
      Test-KeyApi $key | Out-Null
      exit 0
    }
    '^(doctor)$' {
      Write-Say "--- Zcl Doctor ---"
      $healthy = $true
      
      # Node.js check
      if (Get-Command node -ErrorAction SilentlyContinue) {
        $nodeVer = (node -v).Trim()
        Write-Say "✓ Node.js installed ($nodeVer)"
      } else {
        Write-Warn "✗ Node.js not found. Claude Code requires Node.js."
        $healthy = $false
      }
      
      # npm check
      if (Get-Command npm -ErrorAction SilentlyContinue) {
        $npmVer = (npm -v).Trim()
        Write-Say "✓ npm installed ($npmVer)"
      } else {
        Write-Warn "✗ npm not found."
        $healthy = $false
      }
      
      # claude check
      if (Get-Command claude -ErrorAction SilentlyContinue) {
        $claudeVer = (claude --version).Trim()
        Write-Say "✓ Claude Code installed ($claudeVer)"
      } else {
        Write-Warn "✗ Claude Code not found. Will prompt for auto-install on launch."
        $healthy = $false
      }
      
      # API Key
      $key = Get-Key
      if ($key) {
        Write-Say "✓ API Key is configured."
        if (Test-KeyApi $key) {
          Write-Say "✓ API Key can reach Z.ai servers successfully."
        } else {
          Write-Warn "✗ API Key failed validation."
          $healthy = $false
        }
      } else {
        Write-Warn "✗ No API Key set. Run 'zcl config'."
        $healthy = $false
      }
      
      if ($healthy) { Write-Say "`nSystem is fully ready to use Zcl!" }
      else { Write-Warn "`nSome checks failed. Please fix the warnings above." }
      exit 0
    }
    '^(clean)$' {
      Write-Say "Clearing Claude Code memory/cache..."
      $localClaude = Join-Path (Get-Location) ".claude"
      if (Test-Path $localClaude) {
        Remove-Item -Recurse -Force $localClaude
        Write-Say "✓ Removed local project memory ($localClaude)"
      } else {
        Write-Say "✓ No local project memory found."
      }
      exit 0
    }
    '^(alias)$' {
      $aliasName = if ($SubArgs.Count -gt 0) { $SubArgs[0] } else { 'c' }
      if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
      }
      $aliasCmd = "Set-Alias $aliasName zcl"
      Add-Content -Path $PROFILE -Value "`n# Added by zcl`n$aliasCmd"
      Write-Say "✓ Alias '$aliasName' for 'zcl' has been added to your PowerShell profile ($PROFILE)."
      Write-Say "Restart your terminal or run '. `$PROFILE' to use it."
      exit 0
    }"""
code = re.sub(r"    '\^\(verify\|--verify\)\$'.*?      exit 0\n    }", subcommand_block, code, flags=re.DOTALL)

# 5. Add Auto-Install to Main launch block
launch_block_old = """# --- launch ------------------------------------------------------------------
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
  Write-ErrorX "claude CLI not found on PATH.`nInstall Claude Code first: https://docs.claude.com/en/docs/claude-code"
}"""
launch_block_new = """# --- launch ------------------------------------------------------------------
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
    Write-Say "✓ Claude Code installed successfully."
  } else {
    Write-ErrorX "Install Claude Code manually: https://docs.claude.com/en/docs/claude-code"
  }
}"""
code = code.replace(launch_block_old, launch_block_new)

# 6. Add Update Checker at the beginning of Main
checker = """
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
"""
code = code.replace("Write-DebugX \"CONFIG_FILE=$Script:ConfigFile\"", checker + "\nWrite-DebugX \"CONFIG_FILE=$Script:ConfigFile\"")


with open('zcl.ps1', 'w', encoding='utf-8') as f:
    f.write(code)

