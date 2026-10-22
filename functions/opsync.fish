function opsync --description 'Fill OpenProject tasks from a daily report'
    # Usage: opsync [file] [--apply] [--status NAME] [--progress N] [--activity NAME] [--no-time]
    #
    # Report format:
    #     Friday, 16 October 2026
    #
    #     IBB Nasabah BTPNS v3
    #     - Fix issue ... in menu Transfer Batch - 0.5h
    #
    # For each "- <subject> - <n>h" line, finds a work package assigned to you with
    # status "New" whose subject contains <subject>, then sets Actual Start/End Date
    # to the report date, status to "In review", progress to 100%, and logs <n> hours.
    # Dry-run by default; --apply actually writes. Without a file, uses today's
    # laporan-<d><mon>.txt. Auth: OPENPROJECT_API_KEY. Needs curl and jq.
    argparse h/help p/paste apply 'status=' 'progress=!_validate_int' 'activity=' no-time -- $argv
    or return 1

    if set -q _flag_help
        echo 'opsync - fill OpenProject tasks from a daily report

USAGE
    opsync [file] [options]
    opsync --paste [options]

    Without a file, uses today'"'"'s report: laporan-<day><month>.txt
    (e.g. laporan-22okt.txt). The file is looked up in the current folder,
    then in ~/Downloads/openproject-fill.

    Runs as a DRY-RUN by default: only shows how report lines pair with
    tasks, nothing is changed. Use --apply to actually write.

OPTIONS
    -p, --paste        paste the report into the terminal instead of a file,
                       end with Ctrl-D. Saved as laporan-<day><month>.txt
                       (from the report date) in ~/Downloads/openproject-fill;
                       asks before overwriting a different file of that name
    --apply            write the changes to OpenProject
    --status NAME      target status (default: "In review")
    --progress N       progress in percent (default: 100)
    --activity NAME    time entry activity, e.g. "Management"
                       (server default: Development)
    --no-time          only update the tasks, do not log hours
    -h, --help         show this help

REPORT FORMAT
    Thursday, 22 October 2026

    IBB Admin BTPNS v3
    - Fix issue ... in menu Pemeliharaan Role User - 1.5h
    - Investigate issue ... in menu Administrasi User - 1h

    - Date in English: <Weekday>, <day> <Month> <year>
    - Task lines start with "- " and end with "- <hours>h" (0.5h, 1h, 1,5h)
    - Other lines (project names, blank lines) are ignored

WHAT --apply DOES (for each matched task)
    1. Sets Actual Start/End Date to the report date, status to
       In review, progress to 100%
    2. Logs the hours as a time entry on the report date

MATCHING
    - Only tasks assigned to you with status New
    - The report line must be contained in the task subject (case and
      spacing ignored), so prefixes like "UAT IBB Admin : " are fine
    - Each task is used once; lines without a task show NOT FOUND

WARNINGS
    - duplicate line in report: the line appears more than once
    - N tasks match this line: another similar New task exists, likely
      a duplicate created by the KPI master
    Duplicates are compared without punctuation and spacing, so typos like
    "menu -checkbox" vs "menu checkbox" are caught. Letter typos
    (e.g. "chekbox") are not detected.

    If any line is NOT FOUND or has a WARNING, --apply asks first [y/N].

ON FAILURE
    - "not updated (still New)": nothing changed; fix the cause and
      re-run
    - "ACTION NEEDED ... hours NOT logged": the task is already In review
      but its hours were not logged. Log them manually in OpenProject; a
      re-run will skip the task because it is no longer New
    Hours are never logged twice: every time entry is a new record, so the
    task is updated first and the hours are logged after.

EXAMPLES
    opsync                                  # dry-run today'"'"'s report
    opsync --apply                          # apply today'"'"'s report
    opsync -p                               # paste a report, dry-run it
    opsync -p --apply                       # paste a report, apply it
    opsync laporan-21okt.txt                # dry-run a specific file
    opsync laporan-21okt.txt --apply --activity "Management"

REQUIREMENTS
    curl, jq, and OPENPROJECT_API_KEY
    (OpenProject: My account > Access tokens > API).
    OPENPROJECT_URL is optional, default https://openproject.pactindo.com'
        return 0
    end

    set -l dir ~/Downloads/openproject-fill
    set -l months jan feb mar apr mei jun jul agu sep okt nov des
    set -l base https://openproject.pactindo.com
    set -q OPENPROJECT_URL; and set base (string trim -r -c / -- $OPENPROJECT_URL)
    set -l target_name 'In review'
    set -q _flag_status; and set target_name $_flag_status
    set -l progress 100
    set -q _flag_progress; and set progress $_flag_progress

    set -l file laporan-(date +%-d)$months[(date +%-m)].txt
    set -q argv[1]; and set file $argv[1]

    if set -q _flag_paste
        if set -q argv[1]
            echo "Use either --paste or a file, not both"
            return 1
        end
        isatty stdin; and echo 'Paste the report, then press Ctrl-D on an empty line:'
        set -l text (cat)
        # Name the file after the report's own date, e.g. laporan-22okt.txt
        set -l header (string match -r '^\s*\w+,\s*\d{1,2}\s+\w+\s+\d{4}\s*$' -- $text)[1]
        # Check for an empty header first: date -d "" means today, not an error
        set -l day
        test -n "$header"
        and set day (date -d (string replace -r '^\s*\w+,\s*' '' -- $header | string trim) '+%-d %-m' 2>/dev/null)
        or begin
            echo 'No valid date header in the pasted report, e.g. "Thursday, 22 October 2026"'
            return 1
        end
        set day (string split ' ' -- $day)
        set file $dir/laporan-$day[1]$months[$day[2]].txt
        if not test -f $file
            printf '%s\n' $text >$file
            echo "Saved to $file"
        else if printf '%s\n' $text | cmp -s - $file
            echo "Using $file (same content)"
        else
            read -l -P "$file already exists with different content. Overwrite? [y/N] " answer
            if not contains -- (string lower -- "$answer") y yes
                echo "Aborted, $file was not changed."
                return 1
            end
            printf '%s\n' $text >$file
            echo "Saved to $file"
        end
        echo
    end

    if not test -f $file
        set file $dir/$file
    end
    if not test -f $file
        echo "Report not found: $file"
        return 1
    end

    # Parse the report into parallel lists, one entry per task line
    set -l t_line
    set -l t_subj
    set -l t_hours
    set -l t_date
    set -l date
    set -l lineno 0
    while read -l line
        set lineno (math $lineno + 1)
        if string match -qr '^\s*\w+,\s*\d{1,2}\s+\w+\s+\d{4}\s*$' -- $line
            set date (date -d (string replace -r '^\s*\w+,\s*' '' -- $line | string trim) +%F 2>/dev/null)
            or begin
                echo "Line $lineno: date must be in English, e.g. \"Thursday, 22 October 2026\""
                return 1
            end
            continue
        end
        set -l m (string match -rg '(?i)^\s*-\s*(.+?)\s+-\s*(\d+(?:[.,]\d+)?)\s*h\s*$' -- $line)
        or continue
        if test -z "$date"
            echo "Line $lineno: task before any date header"
            return 1
        end
        set -a t_line $lineno
        set -a t_subj (string trim -- $m[1])
        set -a t_hours (string replace , . -- $m[2])
        set -a t_date $date
    end <$file

    set -l n (count $t_subj)
    if test $n -eq 0
        echo "No task lines found"
        return 1
    end
    if not set -q OPENPROJECT_API_KEY
        echo "Set OPENPROJECT_API_KEY first"
        return 1
    end

    set -l statuses (__opsync_req GET $base/api/v3/statuses)
    or begin
        echo $statuses
        return 1
    end
    set -l new_id (__opsync_status $statuses New id)
    or begin
        echo $new_id
        return 1
    end
    set -l target_href (__opsync_status $statuses $target_name _links.self.href)
    or begin
        echo $target_href
        return 1
    end

    set -l filters (jq -nc --arg s $new_id '[{assignee: {operator: "=", values: ["me"]}}, {status: {operator: "=", values: [$s]}}]')
    set -l wps (__opsync_req GET "$base/api/v3/work_packages?pageSize=1000&filters="(jq -rn --arg f $filters '$f | @uri'))
    or begin
        echo $wps
        return 1
    end
    set -l c_id (printf '%s' $wps | jq -r '._embedded.elements[].id')
    set -l c_lock (printf '%s' $wps | jq -r '._embedded.elements[].lockVersion')
    set -l c_schema (printf '%s' $wps | jq -r '._embedded.elements[]._links.schema.href')
    set -l c_subj (printf '%s' $wps | jq -r '._embedded.elements[].subject')
    set -l c_norm
    set -l c_loose
    for s in $c_subj
        set -a c_norm (__opsync_norm $s)
        set -a c_loose (__opsync_loose $s)
    end
    set -l t_norm
    set -l t_loose
    for s in $t_subj
        set -a t_norm (__opsync_norm $s)
        set -a t_loose (__opsync_loose $s)
    end
    echo (count $c_id)' work package(s) assigned to you with status "New"'
    echo

    # Match each line to a distinct work package (duplicate lines -> different WPs).
    # plan[i] is the index into c_* for line i, or 0 when not found.
    set -l used
    set -l plan
    set -l warnings 0
    for i in (seq $n)
        set -l pick 0
        set -l pat (string escape --style=regex -- $t_norm[$i])
        for j in (seq (count $c_id))
            if not contains -- $c_id[$j] $used; and string match -qr -- $pat $c_norm[$j]
                set pick $j
                set -a used $c_id[$j]
                break
            end
        end
        set -a plan $pick

        echo "[line $t_line[$i]] $t_date[$i] $t_hours[$i]h"
        echo "    $t_subj[$i]"
        if test $pick -gt 0
            echo "    -> #$c_id[$pick] $c_subj[$pick]"
        else
            echo "    -> NOT FOUND"
        end

        # Duplicates are compared on letters and digits only, so typo'd copies
        # ("menu -checkbox" vs "menu checkbox") still collide
        set -l others
        set -l typo 0
        for k in (seq $n)
            test $k -eq $i; and continue
            if test "$t_loose[$k]" = "$t_loose[$i]"
                set -a others $t_line[$k]
                test "$t_norm[$k]" != "$t_norm[$i]"; and set typo 1
            end
        end
        if set -q others[1]
            set -l hint
            test $typo -eq 1; and set hint ', differs only in punctuation/spacing'
            echo "    WARNING: duplicate line in report (also line "(string join ', ' $others)"$hint)"
            set warnings (math $warnings + 1)
        end
        set -l similar
        for j in (seq (count $c_id))
            string match -q -- "*$t_loose[$i]*" $c_loose[$j]; and set -a similar $j
        end
        if test (count $similar) -gt (math (count $others) + 1)
            echo "    WARNING: "(count $similar)" tasks match this line, possible duplicate task:"
            for j in $similar
                echo "      #$c_id[$j] $c_subj[$j]"
            end
            set warnings (math $warnings + 1)
        end
    end

    set -l missing (count (string match 0 -- $plan))
    echo
    echo "Matched "(math $n - $missing)"/$n"
    if test $warnings -gt 0
        echo "Warnings: $warnings"
    end
    if not set -q _flag_apply
        echo "Dry-run only. Re-run with --apply to update."
        return 0
    end

    if test $missing -gt 0
        if test $missing -eq $n
            echo "Nothing matched, nothing to update."
            return 1
        end
        echo
        echo "WARNING: $missing line(s) have no matching task in OpenProject:"
        for i in (seq $n)
            test $plan[$i] -eq 0; and echo "  [line $t_line[$i]] $t_subj[$i]"
        end
        read -l -P 'Continue updating the matched tasks only? [y/N] ' answer
        if not contains -- (string lower -- "$answer") y yes
            echo "Aborted, nothing was changed."
            return 1
        end
    end

    if test $warnings -gt 0
        echo
        read -l -P "$warnings warning(s) above. Continue anyway? [y/N] " answer
        if not contains -- (string lower -- "$answer") y yes
            echo "Aborted, nothing was changed."
            return 1
        end
    end

    # Resolve --activity before writing anything, so a typo can't leave tasks half-done.
    # The form endpoint only validates, it doesn't create a time entry.
    set -l activity_href
    if set -q _flag_activity; and not set -q _flag_no_time
        set -l i (contains -i -- (string match -v 0 -- $plan)[1] $plan)
        set -l form_body (jq -nc --arg wp /api/v3/work_packages/$c_id[$plan[$i]] --arg d $t_date[$i] \
            '{_links: {workPackage: {href: $wp}}, hours: "PT1H", spentOn: $d}')
        set -l form (__opsync_req POST $base/api/v3/time_entries/form $form_body)
        or begin
            echo $form
            return 1
        end
        set -l allowed (printf '%s' $form | jq -c '._embedded.schema.activity._embedded.allowedValues')
        set activity_href (printf '%s' $allowed | jq -r --arg n (__opsync_norm $_flag_activity) \
            '.[] | select((.name | ascii_downcase) == $n) | ._links.self.href' | head -1)
        if test -z "$activity_href"
            set -l names (printf '%s' $allowed | jq -r 'map(.name) | join(", ")')
            echo "Activity \"$_flag_activity\" not found. Options: $names"
            echo "Nothing was changed."
            return 1
        end
    end

    set -l schema_hrefs
    set -l schema_jsons
    set -l failed 0
    set -l unlogged
    for i in (seq $n)
        set -l j $plan[$i]
        test $j -eq 0; and continue
        set -l wid $c_id[$j]

        set -l schema
        set -l idx (contains -i -- $c_schema[$j] $schema_hrefs)
        if test -n "$idx"
            set schema $schema_jsons[$idx]
        else
            set schema (__opsync_req GET $base$c_schema[$j])
            or begin
                echo "#$wid FAILED: $schema"
                set failed (math $failed + 1)
                continue
            end
            set -a schema_hrefs $c_schema[$j]
            set -a schema_jsons $schema
        end

        # This instance stores actual dates in the "Baseline" custom fields
        set -l keys (printf '%s' $schema | jq -r '
            [to_entries[]
             | select((.key | startswith("customField")) and .value.type == "Date")
             | {k: .key, n: (.value.name | ascii_downcase)}
             | select(.n | test("actual|baseline"))] as $f
            | ([$f[] | select(.n | test("start"))] | last | .k // ""),
              ([$f[] | select((.n | test("start") | not) and (.n | test("end|finish")))] | last | .k // "")')
        if test -z "$keys[1]"; or test -z "$keys[2]"
            echo "#$wid FAILED: Actual Start/End Date custom fields not found in schema"
            set failed (math $failed + 1)
            continue
        end
        set -l writable (printf '%s' $schema | jq '.percentageDone.writable // false')

        set -l body (jq -nc --argjson lock $c_lock[$j] --arg sk $keys[1] --arg ek $keys[2] \
            --arg d $t_date[$i] --arg st $target_href --argjson w $writable --argjson p $progress \
            '{lockVersion: $lock, ($sk): $d, ($ek): $d, _links: {status: {href: $st}}}
             + (if $w then {percentageDone: $p} else {} end)')
        set -l out (__opsync_req PATCH $base/api/v3/work_packages/$wid $body)
        or begin
            echo "#$wid FAILED: $out"
            set failed (math $failed + 1)
            continue
        end
        echo "#$wid updated"

        set -q _flag_no_time; and continue
        set -l mins (math "round($t_hours[$i] * 60)")
        set -l te (jq -nc --arg wp /api/v3/work_packages/$wid --arg d $t_date[$i] \
            --arg h PT(math "floor($mins / 60)")H(math "$mins % 60")M \
            '{_links: {workPackage: {href: $wp}}, hours: $h, spentOn: $d, comment: {raw: ""}}')
        if test -n "$activity_href"
            set te (printf '%s' $te | jq -c --arg a $activity_href '._links.activity = {href: $a}')
        end
        set out (__opsync_req POST $base/api/v3/time_entries $te)
        or begin
            echo "#$wid FAILED: $out"
            # The task is no longer New, so a re-run won't pick it up again
            set -a unlogged "#$wid  $t_hours[$i]h on $t_date[$i]  $t_subj[$i]"
            continue
        end
        echo "#$wid logged $t_hours[$i]h on $t_date[$i]"
    end

    if set -q unlogged[1]
        echo
        echo "ACTION NEEDED: task updated but hours NOT logged, log these manually in OpenProject:"
        printf '  %s\n' $unlogged
    end
    if test $failed -gt 0
        echo
        echo "$failed task(s) not updated (still New), fix the error and re-run to retry them."
    end
    if set -q unlogged[1]; or test $failed -gt 0
        return 1
    end
end

function __opsync_req
    # Usage: __opsync_req METHOD URL [JSON_BODY]
    # Prints the response as one-line JSON, or the error and returns 1
    set -l tmp (mktemp)
    set -l args -sS -X $argv[1] -u "apikey:$OPENPROJECT_API_KEY" -H 'Content-Type: application/json' -o $tmp -w '%{http_code}'
    set -q argv[3]; and set -a args --data-binary $argv[3]
    set -l code (curl $args $argv[2] 2>/dev/null)
    if not string match -qr '^2' -- "$code"
        set -l path (string replace -r '^https?://[^/]+' '' -- $argv[2])
        set -l err (head -c 500 $tmp | string join ' ')
        test "$code" = 000; and set err 'cannot reach server'
        echo "$argv[1] $path -> $code: $err"
        rm -f $tmp
        return 1
    end
    jq -c . $tmp
    rm -f $tmp
end

function __opsync_status
    # Usage: __opsync_status STATUSES_JSON NAME FIELD  (FIELD: id or _links.self.href)
    set -l value (printf '%s' $argv[1] | jq -r --arg n (__opsync_norm $argv[2]) \
        "._embedded.elements[] | select((.name | ascii_downcase) == \$n) | .$argv[3]" | head -1)
    if test -z "$value"
        echo "Status \"$argv[2]\" not found"
        return 1
    end
    echo $value
end

function __opsync_norm
    string lower -- $argv[1] | string replace -ra '\s+' ' ' | string trim
end

function __opsync_loose
    string lower -- $argv[1] | string replace -ra '[^a-z0-9]' ''
end
