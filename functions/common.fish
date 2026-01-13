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

function dockerlaunch
    # Usage: dockerlaunch project-name image-name tag
    set project $argv[1]
    set image $argv[2]
    set tag $argv[3]

    docker build -t "$image:$tag" .
    docker tag "$image:$tag" nexus.pactindo.com:8443/$project/$image:$tag
    docker push nexus.pactindo.com:8443/$project/$image:$tag
end

function gmr
    if test (count $argv) -lt 3
        echo "Usage:"
        echo "  gmr <source_branch> <target_branch> <reviewer>"
        return 1
    end

    set source_branch $argv[1]
    set target_branch $argv[2]
    set reviewer $argv[3]

    set title "[MR] $source_branch → $target_branch"

    # List commits that not merged to target branch
    set commits (
        git log "$target_branch..$source_branch" \
            --pretty=format:"- %s (%h)" \
        | grep -v "^-\sMerge branch"
    )

    # Show error if no changes between source and target branch
    if test (count $commits) -eq 0
        echo "❌ No changes detected between '$source_branch' and '$target_branch'"
        echo "   Merge request was NOT created."
        return 2
    end
    
    set description "### Changes\n\n"(string join \n $commit_list)

    for c in $commits
        set description "$description$c\n"
    end

    glab mr create \
        -s $source_branch \
        -b $target_branch \
        -a @me \
        --reviewer $reviewer \
        -t "$title" \
        -d "$description" \
        --yes
end
