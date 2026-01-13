# Completion for args 1 and 2 based on branch list
complete -c gmr -f \
    -n 'test (count (commandline -opc)) -le 2' \
    -a '(git branch --format="%(refname:short)")'
