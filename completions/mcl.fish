# mcl completions for fish
#
# Usage: source completions/mcl.fish
#   Or copy to ~/.config/fish/completions/

complete -c mcl -f

# Flags
complete -c mcl -l help    -d 'Show help message'
complete -c mcl -l version -d 'Show version number'
complete -c mcl -l dry-run -d 'Print what would be executed'
complete -c mcl -l verbose -d 'Print debug information'
complete -c mcl -l safe    -d 'Run without --dangerously-skip-permissions'

# Subcommands
complete -c mcl -a config      -d 'Set or change the stored API key'
complete -c mcl -a change-key  -d 'Alias for config'
complete -c mcl -a reset       -d 'Delete the stored API key'
complete -c mcl -a update      -d 'Update to the latest version'
complete -c mcl -a verify      -d 'Verify the stored API key'
complete -c mcl -a show-config -d 'Print current configuration'
complete -c mcl -a help        -d 'Show help message'
