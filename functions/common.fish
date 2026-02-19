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
    
    # ==================================================
    # Resolve assignee username (NO @)
    # ==================================================
    set assignee (glab api user 2>/dev/null | jq -r '.username')

    if test -z "$assignee" -o "$assignee" = "null"
        set assignee "me"
    end

    set title "[MR] $source_branch → $target_branch"

    # =========================
    # Get latest tag from target branch
    # =========================
    set latest_tag (git describe --tags --abbrev=0 $target_branch 2>/dev/null)

    if test -z "$latest_tag"
        set latest_tag "no-tag"
    end

    # =========================
    # Calculate Expected New Tag
    # =========================
    set expected_tag "unknown"

    if test "$latest_tag" != "no-tag"

        set dash_parts (string split "-" $latest_tag)
        set dash_count (count $dash_parts)

        # --------------------------------------------
        # CASE 1: semver-build-labelNumber
        # Example: 1.0.5-600111-DEV1
        # --------------------------------------------
        if test $dash_count -ge 3
            set last_index $dash_count
            set last_part $dash_parts[$last_index]

            if string match -rq '^[A-Za-z]+[0-9]+$' -- $last_part
                set prefix (string replace -r '[0-9]+$' '' $last_part)
                set number (string replace -r '^[^0-9]+' '' $last_part)

                set new_number (math "$number + 1")
                set dash_parts[$last_index] "$prefix$new_number"

                set expected_tag (string join "-" $dash_parts)
            else
                set expected_tag "$latest_tag"
            end

        # --------------------------------------------
        # CASE 2: semver-labelNumber OR semver-build
        # Example: 1.0.1-DEV2
        #          1.0.1-600111
        # --------------------------------------------
        else if test $dash_count -eq 2
            set first_part $dash_parts[1]
            set second_part $dash_parts[2]

            # If label+number (DEV2, RC3, etc)
            if string match -rq '^[A-Za-z]+[0-9]+$' -- $second_part
                set prefix (string replace -r '[0-9]+$' '' $second_part)
                set number (string replace -r '^[^0-9]+' '' $second_part)

                set new_number (math "$number + 1")
                set expected_tag "$first_part-$prefix$new_number"

            # If numeric build
            else if string match -rq '^[0-9]+$' -- $second_part
                set new_build (math "$second_part + 1")
                set expected_tag "$first_part-$new_build"

            else
                set expected_tag "$latest_tag"
            end

        # --------------------------------------------
        # CASE 3: pure semver
        # Example: 1.0.1
        # --------------------------------------------
        else if string match -rq '^[0-9]+\.[0-9]+\.[0-9]+$' -- $latest_tag
            set parts (string split "." $latest_tag)

            set major $parts[1]
            set minor $parts[2]
            set patch $parts[3]

            set new_patch (math "$patch + 1")
            set expected_tag "$major.$minor.$new_patch"

        else
            set expected_tag "$latest_tag"
        end
    end

    # =========================
    # List commits NOT merged
    # =========================
    set commits (
        git log "$target_branch..$source_branch" \
            --no-merges \
            --pretty=format:"- %s (%h)"
    )

    if test (count $commits) -eq 0
        echo "❌ No changes detected between '$source_branch' and '$target_branch'"
        echo "   Merge request was NOT created."
        return 2
    end

    # =========================
    # Multiline description
    # =========================
    set description (
        string join \n -- \
            $commits \
        | string collect
    )

    glab mr create \
        -s "$source_branch" \
        -b "$target_branch" \
        -a "$assignee" \
        --reviewer "$reviewer" \
        -t "$title" \
        -d "$description" \
        --yes

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📌 $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🛠️ Assignee   : $assignee"
    echo "👁️ Reviewer   : $reviewer"
    echo "🏷️ Target Tag : $latest_tag"
    echo "☀️ Latest tag : $expected_tag"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Description:"
    printf "%s\n" "$description"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
end


function vpn
    if test (count $argv) -eq 0
        echo "Usage: vpn <profile>"
        echo "Available profiles:"
        ls ~/.config/openfortivpn
        return 1
    end

    sudo openfortivpn -c ~/.config/openfortivpn/$argv[1]/config
end
