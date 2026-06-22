# ~/.config/fish/completions/gmr_bulk.fish

# Disable file completion
complete -c gmr_bulk -f

# Position 1: target_branch — complete from git branches
complete -c gmr_bulk -n "__fish_gmr_bulk_pos 1" \
    -a "(git branch --format='%(refname:short)' 2>/dev/null)" \
    -d "Target branch"

# Position 2: reviewer — complete from glab members
complete -c gmr_bulk -n "__fish_gmr_bulk_pos 2" \
    -a "(glab api 'projects/:id/members' 2>/dev/null | jq -r '.[].username')" \
    -d "Reviewer"

# Position 3+: source_branches — complete from git branches
complete -c gmr_bulk -n "__fish_gmr_bulk_pos_gte 3" \
    -a "(git branch --format='%(refname:short)' 2>/dev/null)" \
    -d "Source branch"

# Flags: --major --minor --patch --pre
complete -c gmr_bulk -l major -d "Bump major version"
complete -c gmr_bulk -l minor -d "Bump minor version"
complete -c gmr_bulk -l patch -d "Bump patch version"
complete -c gmr_bulk -l pre -d "Bump pre-release version"

# Helper: exact position check
function __fish_gmr_bulk_pos
    set -l pos $argv[1]
    set -l tokens (commandline -opc)
    test (count $tokens) -eq $pos
end

# Helper: position >= N check (for variadic source branches)
function __fish_gmr_bulk_pos_gte
    set -l pos $argv[1]
    set -l tokens (commandline -opc)
    test (count $tokens) -ge $pos
end