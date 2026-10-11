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

    # fzf UI colours for both pickers. Only the terminal's 16 ANSI colours (and
    # -1 for the default fg/bg) are used, so the popup follows the active
    # scheme (Gruvbox Material most of the time) instead of fzf's built-in
    # 256-colour default. bg+ is bright-black, which Gruvbox renders as
    # #3c3836. Move this into $FZF_DEFAULT_OPTS to theme all fzf pickers.
    set -l fzf_colors 'fg:-1,bg:-1,hl:bright-yellow,fg+:bright-white,bg+:bright-black,hl+:bright-yellow:bold,info:cyan,prompt:green,pointer:bright-red,marker:green,spinner:yellow,header:cyan,border:bright-black,label:yellow,query:-1,disabled:bright-black'

    # Parse all cheat sheet TOML files: CMD: lines (fzf entries) and PROV:
    # lines (providers for {{placeholder}} parameters). The abbreviations of
    # the current shell are handed over as well, so the parser can annotate
    # entries whose command has an abbreviation with a →badge.
    set -l python_output (python3 "$parse_py" "$cheat_dir" (abbr --show --color=never | psub))

    if test -z "$python_output"
        echo "No cheat commands found."
        return
    end

    # Extract providers and commands while maintaining line breaks
    set -l providers (printf "%s\n" $python_output | grep '^PROV:')
    set -l commands (printf "%s\n" $python_output | grep '^CMD:')

    # 1. Select the cheat command. Each entry is <display>\t<cmd>\t<abbrs>;
    # fzf shows/searches only the display field but returns the whole line.
    set -l selection (printf "%s\n" $commands | sed 's/^CMD://' | fzf --ansi --color="$fzf_colors" --delimiter='\t' --with-nth=1 --reverse --height=40% --prompt="Cheat Sheet > " --header='→ = existing abbreviation of this command')
    if test -z "$selection"
        return
    end

    # field 1 = display, field 2 = raw command, field 3 = matching abbrs
    set -l fields (string split \t -- $selection)
    set -l cmd $fields[2]

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
            set -l selection (string join \n $list | fzf --ansi --color="$fzf_colors" --reverse --height=40% --prompt="$param_name > ")

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