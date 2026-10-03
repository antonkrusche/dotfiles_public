#!/usr/bin/env fish

set GIT_FZF_DEFAULT_OPTS "--ansi --reverse --height=100% --bind shift-down:preview-down --bind shift-up:preview-up --bind pgdn:preview-page-down --bind pgup:preview-page-up --bind q:abort"

function git-fuzzy-diff-opener -a file parent_hash child_hash
    set PREVIEW_PAGER "delta --diff-so-fancy --line-numbers"

    set PREVIEW_COMMAND "git diff --color=always $parent_hash $child_hash -- $file | $PREVIEW_PAGER"
    set ENTER_COMMAND "$EDITOR +{1} $file"

    bat --color=always --style="numbers" $file | fzf --no-sort --tiebreak=index --ansi --reverse --height=100% --bind shift-down:preview-down --bind shift-up:preview-up --bind pgdn:preview-page-down --bind pgup:preview-page-up --bind q:abort --exit-0 --preview "$PREVIEW_COMMAND" --preview-window=top:50% --bind "enter:execute:$ENTER_COMMAND"
end

function git-fuzzy-diff -a parent_hash child_hash
    if test (count $argv) = 0
        set parent_hash HEAD
        set child_hash
    end

    set PREVIEW_PAGER "delta --diff-so-fancy --line-numbers"

    # Construct preview and enter commands
    set PREVIEW_COMMAND "git diff --color=always $parent_hash $child_hash -- {2} | $PREVIEW_PAGER"
    set ENTER_COMMAND "fish -ic \"git-fuzzy-diff-opener {2} $parent_hash $child_hash\""

    # Debugging: Echo the commands to see if they are constructed properly
    git diff --color=always --name-status -R $parent_hash $child_hash | fzf --ansi --reverse --height=100% --bind shift-down:preview-down --bind shift-up:preview-up --bind pgdn:preview-page-down --bind pgup:preview-page-up --bind q:abort --exit-0 --preview "$PREVIEW_COMMAND" --preview-window=top:85% --bind "enter:execute:$ENTER_COMMAND"
end

function git-fuzzy-log
    set PREVIEW_COMMAND "git show --no-patch --color=always {-1};echo ;git show --stat --format="" --color=always {-1}"
    set ENTER_COMMAND "fish -ic \"git-fuzzy-diff {-1}^1 {-1}\""
    git log $argv --graph --color=always --format="%C(auto) %<(50,trunc)%s %C(green)%C(bold)%<(15,trunc)%cr% %C(blue)%<(15,trunc)%an %C(auto)%d %h" | fzf --no-sort --tiebreak=index --ansi --reverse --height=100% --bind shift-down:preview-down --bind shift-up:preview-up --bind pgdn:preview-page-down --bind pgup:preview-page-up --bind q:abort --exit-0 --preview "$PREVIEW_COMMAND" --preview-window=top:50% --bind "enter:execute:$ENTER_COMMAND"
end

function git-fuzzy-branch-list
    set PREVIEW_COMMAND "echo {1};echo;git log {1} --graph --color=always --format=\"%C(auto) %<(50,trunc)%s %C(green)%C(bold)%<(15,trunc)%cr% %C(blue)%<(15,trunc)%an %C(auto)%d %h\""
    set ENTER_COMMAND "fish -ic \"git-fuzzy-log {1}\""
    git branch -a --color=always --sort=-committerdate --format="%(refname)%09%(color:blue)%(committerdate:relative)" | fzf --ansi --reverse --height=100% --bind shift-down:preview-down --bind shift-up:preview-up --bind pgdn:preview-page-down --bind pgup:preview-page-up --bind q:abort --exit-0 --preview "$PREVIEW_COMMAND" --preview-window=top:85% --bind "enter:execute:$ENTER_COMMAND"
end
