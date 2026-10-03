#!/usr/bin/env fish

function pretty_git_status --description 'Show git status with aligned, exact per-file line counts'
    # Resolve this file's real location (it may be symlinked into
    # ~/.config/fish/functions), then find the python implementation next to it.
    set -l script_dir (dirname (path resolve (status filename)))
    set -l impl "$script_dir/python_utils/pretty_git_status.py"

    if test -f "$impl"; and command -q python3
        python3 "$impl"
    else
        # Degrade gracefully without python or if the implementation is missing.
        git status -sb
    end
end