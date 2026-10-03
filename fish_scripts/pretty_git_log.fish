#!/usr/bin/env fish

function pretty_git_log --wraps 'git log' --description 'Show a compact, colored git log graph'
    git log --graph --color=always \
        --format='%C(auto) %<(50,trunc)%s %C(green)%C(bold)%<(15,trunc)%cr% %C(blue)%<(15,trunc)%an %C(auto)%h %C(auto)%d' \
        -n 8 $argv
end
