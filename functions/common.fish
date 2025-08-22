# Git Config
alias gline="git log --all --decorate --oneline --graph"
alias gleap="git switch"
alias gcheck="git checkout"
alias gstage="git commit -m"
alias gpull="git pull"
alias ggrab="git pull --all"
alias gpush="git push"
alias gsave="git pull; git add .; git commit -m"
alias gmelt="git merge --no-ff"
alias gnote="git diff --name-only HEAD^ HEAD"

function gcall
    git tag -a "$argv[1]" -m "$argv[2]"
    git push origin "$argv[1]"
end

function gbstem
    git branch "$argv[1]"
    git push --set-upstream origin "$argv[1]"
end

function gbcuts
    git branch -d "$argv[1]"
    git push --delete origin "$argv[1]"
end

# NVM Config
alias nrs18="nvm use 18; npm run serve"
alias nrs16="nvm use 16; npm run serve"
alias nrs14="nvm use 14; npm run serve"

# Apt Config
alias a-update="sudo apt update"
alias a-upgrade="sudo apt upgrade"

# Tar Config
alias comp="tar -zcvf"
alias extr="tar -zxvf"

# Explorer Config
alias nopen="xdg-open ."
alias eopen="explorer.exe ."

# Python Config
alias python=python3
alias pip=pip3