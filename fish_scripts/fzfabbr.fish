function git_fuzzy_branch -a PREVIEW_COMMAND
    set PREVIEW_COMMAND "echo {1};echo;git log {1} --graph --color=always --format=\"%C(auto) %<(50,trunc)%s %C(green)%C(bold)%<(15,trunc)%cr% %C(blue)%<(15,trunc)%an %C(auto)%d %h\""
    set result (git branch -a --color=always --sort=-committerdate --format="%(refname)%09%(color:blue)%(committerdate:relative)" | fzf --ansi --reverse --height=100% --bind shift-down:preview-down --bind shift-up:preview-up --bind pgdn:preview-page-down --bind pgup:preview-page-up --bind q:abort --exit-0 --preview "$PREVIEW_COMMAND" --preview-window=top:85% --bind 'enter:become(echo {1})')
    echo $result
end

function git_fuzzy_checkout_branch
    set PREVIEW_COMMAND "echo git checkout {1};echo;git log {1} --graph --color=always --format=\"%C(auto) %<(50,trunc)%s %C(green)%C(bold)%<(15,trunc)%cr% %C(blue)%<(15,trunc)%an %C(auto)%d %h\""
    set result (git branch -a --color=always --sort=-committerdate --format="%(refname)%09%(color:blue)%(committerdate:relative)" | fzf --ansi --reverse --height=100% --bind shift-down:preview-down --bind shift-up:preview-up --bind pgdn:preview-page-down --bind pgup:preview-page-up --bind q:abort --exit-0 --preview "$PREVIEW_COMMAND" --preview-window=top:85% --bind 'enter:become(echo {1})')
    echo git checkout $result
end
