# ~/.config/fish/completions/gmr.fish

# Disable file completion
complete -c gmr -f

# Position 1: source_branch
complete -c gmr -n 'test (count (commandline -opc)) -eq 1' \
    -a '(git branch --format="%(refname:short)" 2>/dev/null)' \
    -d "Source branch"

# Position 2: target_branch
complete -c gmr -n 'test (count (commandline -opc)) -eq 2' \
    -a '(git branch --format="%(refname:short)" 2>/dev/null)' \
    -d "Target branch"

# Position 3: reviewer
complete -c gmr -n 'test (count (commandline -opc)) -eq 3' \
    -a '(glab api "projects/:id/members" 2>/dev/null | jq -r ".[].username")' \
    -d "Reviewer"

# Flags: --major --minor --patch --pre (available at any position)
complete -c gmr -l major -d "Bump major version"
complete -c gmr -l minor -d "Bump minor version"
complete -c gmr -l patch -d "Bump patch version"
complete -c gmr -l pre -d "Bump pre-release version"
