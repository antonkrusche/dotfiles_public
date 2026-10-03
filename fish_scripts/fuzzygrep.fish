#!/usr/bin/env fish
# Based on the "Ripgrep integration" example from the fzf repository
# (https://github.com/junegunn/fzf/blob/master/ADVANCED.md), MIT licensed,
# adapted for fish.

function fuzzygrep
    # Switch between Ripgrep launcher mode (CTRL-R) and fzf filtering mode (CTRL-F)
    rm -f /tmp/rg-fzf-{r,f}
    set RG_PREFIX "rg --column --line-number --no-heading --color=always --smart-case "

    if test (count $argv) -gt 0
        set INITIAL_QUERY "$argv"
    else
        set INITIAL_QUERY ""
    end

    set result (
        echo "" | fzf --ansi --disabled --query "$INITIAL_QUERY" --bind "start:reload($RG_PREFIX {q})+unbind(ctrl-r)" --bind "change:reload:sleep 0.1; $RG_PREFIX {q} || true" --bind "ctrl-f:unbind(change,ctrl-f)+change-prompt(2. fzf> )+enable-search+rebind(ctrl-r)+transform-query(echo {q} > /tmp/rg-fzf-r; cat /tmp/rg-fzf-f)" --bind "ctrl-r:unbind(ctrl-r)+change-prompt(1. ripgrep> )+disable-search+reload($RG_PREFIX {q} || true)+rebind(change,ctrl-f)+transform-query(echo {q} > /tmp/rg-fzf-f; cat /tmp/rg-fzf-r)" --color "hl:-1:underline,hl+:-1:underline:reverse" --prompt '1. ripgrep> ' --delimiter : --header '╱ CTRL-R (ripgrep mode) ╱ CTRL-F (fzf mode) ╱' --preview 'bat --color=always {1} --highlight-line {2}' --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
        )

    echo $result

    set -x lgfile (string split ":" $result)[1]
    echo $lgfile
    set linenumber (echo "$result" | cut -d: -f2)
    if test -n "$lgfile"
        $EDITOR +"$linenumber" "$lgfile"
    end
    echo $EDITOR "$linenumber" "$lgfile"
end
