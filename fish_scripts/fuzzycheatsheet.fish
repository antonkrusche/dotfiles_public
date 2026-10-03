#!/usr/bin/env fish

function fuzzy-cheat-sheet
    # Resolve this file's real location (it may be symlinked into
    # ~/.config/fish/functions), then find the helpers and cheatsheets.
    set -l script_dir (dirname (path resolve (status filename)))
    set -l cheat_dir (path resolve $script_dir/../cheatsheets)
    set -l parse_py "$script_dir/python_utils/parse_cheatsheets.py"

    if not command -q python3
        echo "fuzzy-cheat-sheet: python3 not found" >&2
        return 1
    end

    # Parse all cheat sheet TOML files: CMD: lines (fzf entries) and PROV:
    # lines (providers for {{placeholder}} parameters).
    set -l python_output (python3 "$parse_py" "$cheat_dir")

    if test -z "$python_output"
        echo "No cheat commands found."
        return
    end

    # Extract providers and commands while maintaining line breaks
    set -l providers (printf "%s\n" $python_output | grep '^PROV:')
    set -l commands (printf "%s\n" $python_output | grep '^CMD:')

    # 1. Select the cheat command
    set -l selection (printf "%s\n" $commands | sed 's/^CMD://' | fzf --ansi --reverse --height=40% --prompt="Cheat Sheet > ")
    if test -z "$selection"
        return
    end

    # Extract the part before the metadata pipe, then the command after the first ': '
    set -l clean_line (printf '%s\n' "$selection" | cut -d'|' -f1)
    set -l cmd (printf '%s\n' "$clean_line" | awk -F': ' '{print $2}')

    # 2. Check if the command has parameter placeholders {{...}}
    # Use a while loop to resolve ALL placeholders one by one
    while string match -qr '\{\{.*\}\}' "$cmd"
        # Extract the first placeholder found
        set -l param_full (string match -r '\{\{[^}]*\}\}' "$cmd")[1]
        # Use a very simple non-regex replacement to remove the braces
        set -l param_name (string replace '{{' '' $param_full)
        set -l param_name (string replace '}}' '' $param_name)

        # Look up the provider command from our providers list
        set -l provider_entry ""
        for p in $providers
            if string match -q "PROV:$param_name:*" $p
                set provider_entry (printf '%s\n' "$p" | cut -d':' -f3-)
                break
            end
        end

        set -l param_value ""
        if test -n "$provider_entry"
            # Split provider into list_cmd and extract_cmd
            set -l parts (string split "|" $provider_entry)
            set -l list_cmd (string trim $parts[1])

            # Generate the list for fzf
            set -l list (eval $list_cmd)

            # Select the item from the list
            set -l selection (string join \n $list | fzf --ansi --reverse --height=40% --prompt="$param_name > ")

            if test -z "$selection"
                return
            end

            # If an extract_cmd exists, use it to clean the selection
            if test (count $parts) -gt 1
                set -l extract_cmd (string trim $parts[2])
                set param_value (printf '%s\n' "$selection" | eval $extract_cmd)
            else
                set param_value $selection
            end
        else
            # Fallback for missing provider (-P = literal prompt string;
            # -p would execute the string as a shell command!)
            read -P "No provider for $param_name. Enter value: " param_value
        end

        # Replace ONLY the first occurrence of the current placeholder. This is
        # a literal replace on purpose: with -r the replacement string would be
        # interpreted as a regex replacement, mangling values containing '\'
        # (e.g. Windows paths) or wiping $cmd on substitution errors.
        set cmd (string replace "$param_full" "$param_value" "$cmd")
    end

    # 4. Inject into the command line
    commandline -r $cmd
end