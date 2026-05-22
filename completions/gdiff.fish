# Disable file completion
complete -c gdiff -f

# Complete with local branches
complete -c gdiff -n "__fish_is_nth_token 1" -a "(git branch --format='%(refname:short)' 2>/dev/null)" -d "base branch"

# Complete with local branches
complete -c gdiff -n "__fish_is_nth_token 2" -a "(git branch --format='%(refname:short)' 2>/dev/null)" -d "compare branch"