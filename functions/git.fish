# Git Config
alias gline="git log --all --decorate --oneline --graph"
alias gleap="git switch"
alias gpull="git fetch; git pull"
alias ggrab="git pull --all"
alias gpush="git push"
alias gsave="git pull; git add .; git commit -m"
alias gmelt="git merge --no-ff"
alias getch="git fetch"
alias gpick="git stash push --"

function gcall
    git tag -a "$argv[1]" -m "$argv[2]"
    git push origin "$argv[1]"
end

function gbstem
    git branch "$argv[1]"
    git push --set-upstream origin "$argv[1]"
end

function gbcuts
    set -l force 0
    set -l branches

    for arg in $argv
        switch $arg
            case -f --force
                set force 1
            case '*'
                set branches $branches $arg
        end
    end

    if test (count $branches) -lt 1
        echo "Usage:"
        echo "  gbcuts [-f|--force] <branch1> [branch2] ..."
        return 1
    end

    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    or begin
        echo "❌ Not inside a git repository."
        return 1
    end

    set failed_branches
    set success_branches

    for branch in $branches
        echo "🗑️  Deleting $branch..."

        if test $force -eq 1
            git branch -D "$branch" 2>/dev/null
        else
            git branch -d "$branch" 2>/dev/null
        end
        set local_code $status

        git push --delete origin "$branch" 2>/dev/null
        set remote_code $status

        if test $local_code -eq 0 -a $remote_code -eq 0
            set success_branches $success_branches $branch
        else
            set failed_branches $failed_branches $branch
        end
    end

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if test (count $success_branches) -gt 0
        echo "✅ Successfully deleted:"
        for branch in $success_branches
            echo "   • $branch"
        end
    end

    if test (count $failed_branches) -gt 0
        echo "❌ Failed to delete:"
        for branch in $failed_branches
            echo "   • $branch"
        end
    end
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
end

function gdiff
    if test (count $argv) -lt 2
        echo "Usage:"
        echo "  gdiff <base_branch> <compare_branch>"
        echo ""
        echo "Example:"
        echo "  gdiff staging feature/28-registrasi-migrasi-mb"
        return 1
    end

    set base_branch $argv[1]
    set compare_branch $argv[2]

    git diff --name-status $base_branch...$compare_branch
end

function gwipe
  set branches (git branch -vv | grep ': gone]' | awk '{print $1}')

  if test -z "$branches"
    echo "No stale branches to delete."
    return
  end

  set force_flag "-d"
  if contains -- --force $argv
    set force_flag "-D"
  end

  echo "Branches to delete:"
  for branch in $branches
    echo "  $branch"
  end
  echo
  read --prompt-str "Delete these branches? [y/N] " reply

  if string match -qr '^[Yy]$' $reply
    for branch in $branches
      git branch $force_flag $branch
      if test $status -eq 0
        echo "  ✓ deleted $branch"
      else
        echo "  ✗ failed  $branch"
      end
    end
  else
    echo "Aborted."
  end
end

function gver
    set -l bump ""
    set -l branch ""

    for arg in $argv
        switch $arg
            case --major
                set bump major
            case --minor
                set bump minor
            case --patch
                set bump patch
            case --pre
                set bump pre
            case '*'
                set branch $arg
        end
    end

    # Default branch: origin/<current branch>
    if test -z "$branch"
        set branch "origin/"(git branch --show-current 2>/dev/null)
    end

    # Get latest tag from the branch
    set latest_tag (git describe --tags --abbrev=0 $branch 2>/dev/null)

    if test -z "$latest_tag"
        echo "❌ No tags found on $branch"
        return 1
    end

    # Split by first dash to separate semver from pre-release
    set dash_parts (string split -m1 "-" $latest_tag)
    set semver $dash_parts[1]
    set prerelease ""

    if test (count $dash_parts) -ge 2
        set prerelease $dash_parts[2]
    end

    # Parse semver
    set sem_parts (string split "." $semver)
    set major $sem_parts[1]
    set minor $sem_parts[2]
    set patch $sem_parts[3]

    # Smart default: if has pre-release, bump pre; otherwise bump patch
    if test -z "$bump"
        if test -n "$prerelease"
            set bump pre
        else
            set bump patch
        end
    end

    # Calculate new version
    switch $bump
        case major
            set major (math "$major + 1")
            set minor 0
            set patch 0
            # Reset pre-release trailing number to 1 if exists
            if test -n "$prerelease"
                set pre_segments (string split "-" $prerelease)
                set last_idx (count $pre_segments)
                set last_seg $pre_segments[$last_idx]
                if string match -rq '[0-9]+$' -- $last_seg
                    set prefix (string replace -r '[0-9]+$' '' $last_seg)
                    set pre_segments[$last_idx] "$prefix"1
                end
                set prerelease (string join "-" $pre_segments)
            end
        case minor
            set minor (math "$minor + 1")
            set patch 0
            # Reset pre-release trailing number to 1 if exists
            if test -n "$prerelease"
                set pre_segments (string split "-" $prerelease)
                set last_idx (count $pre_segments)
                set last_seg $pre_segments[$last_idx]
                if string match -rq '[0-9]+$' -- $last_seg
                    set prefix (string replace -r '[0-9]+$' '' $last_seg)
                    set pre_segments[$last_idx] "$prefix"1
                end
                set prerelease (string join "-" $pre_segments)
            end
        case patch
            set patch (math "$patch + 1")
            # Reset pre-release trailing number to 1 if exists
            if test -n "$prerelease"
                set pre_segments (string split "-" $prerelease)
                set last_idx (count $pre_segments)
                set last_seg $pre_segments[$last_idx]
                if string match -rq '[0-9]+$' -- $last_seg
                    set prefix (string replace -r '[0-9]+$' '' $last_seg)
                    set pre_segments[$last_idx] "$prefix"1
                end
                set prerelease (string join "-" $pre_segments)
            end
        case pre
            if test -z "$prerelease"
                echo "⚠️  No pre-release label to bump on tag: $latest_tag"
                return 1
            end

            # Increment trailing number of the last dash-segment
            # e.g. "600111-DEV1" -> last segment is "DEV1" -> "DEV2"
            set pre_segments (string split "-" $prerelease)
            set last_idx (count $pre_segments)
            set last_seg $pre_segments[$last_idx]

            if string match -rq '[0-9]+$' -- $last_seg
                set prefix (string replace -r '[0-9]+$' '' $last_seg)
                set number (string match -r '[0-9]+$' -- $last_seg)
                set new_number (math "$number + 1")
                set pre_segments[$last_idx] "$prefix$new_number"
            else
                echo "⚠️  Cannot bump pre-release: no trailing number in '$last_seg'"
                return 1
            end

            set prerelease (string join "-" $pre_segments)
    end

    # Build result
    set new_semver "$major.$minor.$patch"

    if test -n "$prerelease"
        echo "$new_semver-$prerelease"
    else
        echo "$new_semver"
    end
end

function gmr
    if test (count $argv) -lt 3
        echo "Usage:"
        echo "  gmr <source_branch> <target_branch> <reviewer> [--major|--minor|--patch|--pre]"
        return 1
    end

    set -l bump_flag ""
    set -l positional

    for arg in $argv
        switch $arg
            case --major --minor --patch --pre
                set bump_flag $arg
            case '*'
                set positional $positional $arg
        end
    end

    if test (count $positional) -lt 3
        echo "Usage:"
        echo "  gmr <source_branch> <target_branch> <reviewer> [--major|--minor|--patch|--pre]"
        return 1
    end

    set source_branch $positional[1]
    set target_branch $positional[2]
    set reviewer $positional[3]

    # ==================================================
    # Ensure inside git repo
    # ==================================================
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    or begin
        echo "❌ Not inside a git repository."
        return 1
    end

    # ==================================================
    # Fetch latest from origin
    # ==================================================
    git fetch --prune --tags origin >/dev/null 2>&1

    set remote_target "origin/$target_branch"
    
    # ==================================================
    # Resolve assignee username (NO @)
    # ==================================================
    set assignee (glab api user 2>/dev/null | jq -r '.username')

    if test -z "$assignee" -o "$assignee" = "null"
        set assignee "me"
    end

    set title "[MR] $source_branch → $target_branch"

    # =========================
    # Get latest tag from REMOTE target branch
    # =========================
    set latest_tag (git describe --tags --abbrev=0 $remote_target 2>/dev/null)

    if test -z "$latest_tag"
        set latest_tag "no-tag"
    end

    # =========================
    # Calculate Expected New Tag (using gver)
    # =========================
    set expected_tag "unknown"

    if test "$latest_tag" != "no-tag"
        set expected_tag (gver $bump_flag $remote_target)
        if test $status -ne 0
            set expected_tag "$latest_tag"
        end
    end

    # =========================
    # List commits NOT merged
    # =========================
    set commits (
        git log "$remote_target..$source_branch" \
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

    set mr_output (glab mr create \
        -s "$source_branch" \
        -b "$target_branch" \
        -a "$assignee" \
        --reviewer "$reviewer" \
        -t "$title" \
        -d "$description" \
        --yes 2>&1)
    set mr_exit_code $status

    if test $mr_exit_code -ne 0
        echo "❌ Failed to create MR:"
        printf "%s\n" $mr_output
        return 1
    end

    # ==================================================
    # Extract MR link from glab output
    # ==================================================
    set mr_link ""
    for line in $mr_output
        if string match -rq 'https?://[^\s]+merge_requests/[0-9]+' -- $line
            set mr_link (string match -r 'https?://[^\s]+merge_requests/[0-9]+' -- $line)
            break
        end
    end

    if test -z "$mr_link"
        set mr_link "unknown"
    end

    # ==================================================
    # Log MR success
    # ==================================================
    set log_dir ~/.local/share/fish/logs
    mkdir -p $log_dir

    set log_file $log_dir/merge-(date "+%Y%m%d").log
    set timestamp (date "+%Y-%m-%d %H:%M:%S")
    set log_description (string join "" -- $commits | string collect)

    set log_entry "[$timestamp] $mr_link | $source_branch → $target_branch | $latest_tag → $expected_tag | assignee=$assignee | reviewer=$reviewer"

    echo $log_entry >> $log_file
    printf "%s\n" $commits >> $log_file
    echo "" >> $log_file

    echo "$mr_link"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📌 $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🛠️ Assignee       : $assignee"
    echo "👁️ Reviewer       : $reviewer"
    echo "🏷️ Target Tag     : $latest_tag"
    echo "☀️ Latest tag     : $expected_tag"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📝 Description:"
    printf "%s\n" "$description"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
end

function gmr_bulk
    if test (count $argv) -lt 3
        echo "Usage:"
        echo "  gmr_bulk <target_branch> <reviewer> <source_branch1> [source_branch2] ... [--major|--minor|--patch|--pre]"
        return 1
    end

    set -l bump_flag ""
    set -l positional

    for arg in $argv
        switch $arg
            case --major --minor --patch --pre
                set bump_flag $arg
            case '*'
                set positional $positional $arg
        end
    end

    if test (count $positional) -lt 3
        echo "Usage:"
        echo "  gmr_bulk <target_branch> <reviewer> <source_branch1> [source_branch2] ... [--major|--minor|--patch|--pre]"
        return 1
    end

    set target_branch $positional[1]
    set reviewer $positional[2]
    set source_branches $positional[3..]

    # ==================================================
    # Ensure inside git repo
    # ==================================================
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    or begin
        echo "❌ Not inside a git repository."
        return 1
    end

    set failed_branches
    set no_changes_branches

    for source_branch in $source_branches
        set result (gmr $source_branch $target_branch $reviewer $bump_flag 2>&1)
        set exit_code $status

        if test $exit_code -eq 0
            printf "%s\n" $result
            echo
        else if test $exit_code -eq 2
            set no_changes_branches $no_changes_branches $source_branch
        else
            set failed_branches $failed_branches $source_branch
        end
    end

    # ==================================================
    # Report no changes branches
    # ==================================================
    if test (count $no_changes_branches) -gt 0
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⚠️  No changes detected (MR skipped):"
        for branch in $no_changes_branches
            echo "   • $branch"
        end
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    end

    # ==================================================
    # Report failed branches
    # ==================================================
    if test (count $failed_branches) -gt 0
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "❌ Failed to create MR:"
        for branch in $failed_branches
            echo "   • $branch"
        end
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    end
end
