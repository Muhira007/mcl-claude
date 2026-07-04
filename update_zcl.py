import re

with open('zcl', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update Version
code = re.sub(r"VERSION='1\.0\.0'", "VERSION='1.1.0'", code)

# 2. Add subcommands to Help Menu
help_addition = """  zcl model              Interactively select the Z.ai model to use
  zcl doctor             Run diagnostic checks
  zcl clean              Clear local Claude Code cache/memory
  zcl alias [NAME]       Create a shell shortcut (e.g. zcl alias c)"""
code = code.replace("  zcl model              Interactively select the Z.ai model to use", help_addition)

# 3. Add subcommands to main arguments loop
regex_old = r"    reset\|--reset\|model\|models\|--model\|--models\|update\|--update\|upgrade\|--upgrade\|\\\n    verify\|--verify\|show-config\|--show-config\|show\|--show\)"
regex_new = r"    reset|--reset|model|models|--model|--models|update|--update|upgrade|--upgrade|\n    verify|--verify|show-config|--show-config|show|--show|doctor|clean|alias)"
code = code.replace(regex_old, regex_new)

# 4. Implement commands in handle_subcommand
subcommand_block = """    verify|--verify)
      local key; key="$(read_key || true)"
      if [ -z "$key" ]; then
        die "No stored key. Run 'zcl config' first."
      fi
      say "Stored key: ${key:0:5}...${key: -4} (${#key} chars)"
      if validate_key_format "$key"; then
        say "Format:  ✓"
      else
        warn "Format:  ✗ (unusual format)"
      fi
      verify_key_api "$key" || true
      exit 0
      ;;
    doctor)
      say "--- Zcl Doctor ---"
      local healthy=1
      
      if command -v node >/dev/null 2>&1; then
        say "✓ Node.js installed ($(node -v))"
      else
        warn "✗ Node.js not found. Claude Code requires Node.js."
        healthy=0
      fi
      
      if command -v npm >/dev/null 2>&1; then
        say "✓ npm installed ($(npm -v))"
      else
        warn "✗ npm not found."
        healthy=0
      fi
      
      if command -v claude >/dev/null 2>&1; then
        say "✓ Claude Code installed ($(claude --version 2>/dev/null || echo "unknown"))"
      else
        warn "✗ Claude Code not found. Will prompt for auto-install on launch."
        healthy=0
      fi
      
      local key; key="$(read_key || true)"
      if [ -n "$key" ]; then
        say "✓ API Key is configured."
        if curl -fsSL -X GET -H "Authorization: Bearer $key" --max-time 10 https://api.z.ai/api/paas/v4/models >/dev/null 2>&1; then
          say "✓ API Key can reach Z.ai servers successfully."
        else
          warn "✗ API Key failed validation."
          healthy=0
        fi
      else
        warn "✗ No API Key set. Run 'zcl config'."
        healthy=0
      fi
      
      if [ "$healthy" -eq 1 ]; then
        say "\nSystem is fully ready to use Zcl!"
      else
        warn "\nSome checks failed. Please fix the warnings above."
      fi
      exit 0
      ;;
    clean)
      say "Clearing Claude Code memory/cache..."
      if [ -d "./.claude" ]; then
        rm -rf "./.claude"
        say "✓ Removed local project memory (./.claude)"
      else
        say "✓ No local project memory found."
      fi
      exit 0
      ;;
    alias)
      local aliasName="${2:-c}"
      local rc_file=""
      if [ -n "$ZSH_VERSION" ]; then
        rc_file="$HOME/.zshrc"
      elif [ -n "$BASH_VERSION" ]; then
        rc_file="$HOME/.bashrc"
      else
        rc_file="$HOME/.bashrc"
      fi
      echo "alias $aliasName='zcl'" >> "$rc_file"
      say "✓ Alias '$aliasName' for 'zcl' has been added to $rc_file"
      say "Restart your terminal or run 'source $rc_file' to use it."
      exit 0
      ;;"""
code = re.sub(r"    verify\|--verify\).*?      exit 0\n      ;;", subcommand_block, code, flags=re.DOTALL)

# 5. Add Auto-Install to Launch block
launch_block_old = """if ! command -v claude >/dev/null 2>&1; then
  die "claude CLI not found on PATH.\nInstall Claude Code first: https://docs.claude.com/en/docs/claude-code"
fi"""
launch_block_new = """if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI not found on PATH."
  printf "Would you like Zcl to automatically install Claude Code via npm? [Y/n] "
  read -r ans
  if [[ "$ans" =~ ^[Nn] ]]; then
    die "Install Claude Code manually: https://docs.claude.com/en/docs/claude-code"
  else
    if ! command -v npm >/dev/null 2>&1; then
      die "npm is not installed! Please install Node.js first."
    fi
    say "Installing @anthropic-ai/claude-code globally..."
    npm install -g @anthropic-ai/claude-code || die "Installation failed."
    say "✓ Claude Code installed successfully."
  fi
fi"""
code = code.replace(launch_block_old, launch_block_new)

# 6. Add Update Checker
checker = """
check_for_updates() {
  local last_check_file="$CONFIG_DIR/last_update_check"
  local current_time
  current_time=$(date +%s)
  
  if [ -f "$last_check_file" ]; then
    local last_check
    last_check=$(cat "$last_check_file")
    if [ $((current_time - last_check)) -lt 86400 ]; then
      return 0
    fi
  fi
  
  if command -v curl >/dev/null 2>&1; then
    local remote_ver
    remote_ver=$(curl -fsSL --max-time 2 "https://raw.githubusercontent.com/Muhira007/z-ai-claude/main/VERSION" 2>/dev/null)
    if [ -n "$remote_ver" ] && [ "$remote_ver" != "$VERSION" ] && [[ "$remote_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
      printf "\\033[33m\\n🚀 New version of Zcl is available (%s)! Run 'zcl update' to install.\\n\\n\\033[0m" "$remote_ver" >&2
    fi
  fi
  echo "$current_time" > "$last_check_file"
}
check_for_updates &>/dev/null &
"""
code = code.replace("debug \"CONFIG_FILE=$CONFIG_FILE\"", checker + "\ndebug \"CONFIG_FILE=$CONFIG_FILE\"")

with open('zcl', 'w', encoding='utf-8') as f:
    f.write(code)

