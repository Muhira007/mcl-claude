#compdef mcl

# mcl completions for zsh
#
# Usage: source completions/mcl.zsh
#   Or copy to a directory in $fpath.

_mcl() {
  local -a subcommands flags

  subcommands=(
    'config:Set or change the stored API key'
    'change-key:Alias for config'
    'reset:Delete the stored API key'
    'update:Update to the latest version'
    'verify:Verify the stored API key against MiMo API'
    'show-config:Print current configuration'
    'help:Show help message'
  )

  flags=(
    '--help[Show help message]'
    '--version[Show version number]'
    '--dry-run[Print what would be executed]'
    '--verbose[Print debug information]'
    '--safe[Run without --dangerously-skip-permissions]'
  )

  _arguments -s \
    $flags \
    '1: :_alternative "subcmd:subcommand:(( ${subcommands} ))" "args:arguments:_default"' \
    '*::args:_default'
}

_mcl "$@"
