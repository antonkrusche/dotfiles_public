#!/usr/bin/env fish

function _pretty_git_status_impl
    # Resolve this file's real location (it may be symlinked into
    # ~/.config/fish/functions), then find the python implementation next to it.
    set -l script_dir (dirname (path resolve (status filename)))
    echo "$script_dir/python_utils/pretty_git_status.py"
end

function pretty_git_status --description 'Show git status with aligned, exact per-file line counts'
    set -l impl (_pretty_git_status_impl)
    if test -f "$impl"; and command -q python3
        python3 "$impl"
    else
        git status -sb
    end
end

function pretty_git_status_rows --description 'One "display<TAB>repo-relative-path" row per change, for fuzzy pickers'
    set -l impl (_pretty_git_status_impl)
    if test -f "$impl"; and command -q python3
        # Export the live terminal width: python consults only the COLUMNS
        # *environment* variable (fish's $COLUMNS is not exported), and this
        # wrapper is meant to be captured via command substitution.
        begin
            set -lx COLUMNS $COLUMNS
            python3 "$impl" --pairs
        end
    else
        _pretty_git_status_rows_fallback
    end
end

function _pretty_git_status_rows_fallback
    # Degraded mode (no python3 or implementation missing): colored porcelain
    # rows, without path elision or per-file line counts.
    set -l red (set_color red)
    set -l green (set_color green)
    set -l normal (set_color normal)

    set -l records (git status --porcelain -z | string split0)
    set -l rows
    while set -q records[1]
        set -l rec $records[1]
        set -e records[1]
        set -l xy (string sub -s 1 -e 2 -- $rec)
        set -l path (string sub -s 4 -- $rec)

        if test "$xy" = '??'
            set xycol "$red$xy$normal"
        else
            set -l sx (string sub -s 1 -e 1 -- $xy)
            set -l sy (string sub -s 2 -e 2 -- $xy)
            not string match -rq '[ ?]' -- $sx; and set sx "$green$sx$normal"
            not string match -rq '[ ?]' -- $sy; and set sy "$red$sy$normal"
            set xycol "$sx$sy"
        end

        # Rename/copy records come in pairs (destination first, then the bare
        # source path, without an XY prefix).
        set -l orig
        if string match -qr '^[RC]' -- $rec; and set -q records[1]
            set orig $records[1]
            set -e records[1]
        end

        if test -n "$orig"
            printf '%s\t%s\n' "$xycol $orig -> $path" "$path"
        else
            printf '%s\t%s\n' "$xycol $path" "$path"
        end
    end
end
