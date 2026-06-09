# ~/.config/fish/completions/gbcuts.fish

complete -c gbcuts -f

# Flags
complete -c gbcuts -s f -l force -d "Force delete (unmerged branches)"

# Branches — exclude current branch & already-typed ones
complete -c gbcuts -n "not __fish_seen_subcommand_from (git branch --format='%(refname:short)' 2>/dev/null)" \
    -a "(git branch --format='%(refname:short)' 2>/dev/null | grep -v '^\*')" \
    -d "Local branch"