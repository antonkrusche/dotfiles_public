# git_fuzzy_* pickers: fzf frontend over git data that prints the selection,
# meant to be consumed via `abbr --function` (like gfb in config.fish) or
# command substitution.

# Common fzf arguments for the git pickers in this file and fuzzygit.fish
# (kept in sync with the definition at the top of fuzzygit.fish). Defined as a
# fish LIST so each flag reaches fzf as its own argument, and NOT exported —
# despite the name, fzf must not see this as its env override.
set -q GIT_FZF_DEFAULT_OPTS; or set GIT_FZF_DEFAULT_OPTS \
    --ansi --reverse --height=100% --exit-0 \
    --bind shift-down:preview-down --bind shift-up:preview-up \
    --bind pgdn:preview-page-down --bind pgup:preview-page-up \
    --bind q:abort

if not functions -q pretty_git_status_rows
    source (dirname (path resolve (status filename)))/pretty_git_status.fish
end

function _git_fuzzy_branch_input
    git branch -a --color=always --sort=-committerdate \
        --format="%(refname)%09%(color:blue)%(committerdate:relative)"
end

function git_fuzzy_branch --description 'Pick a branch via fzf, print its name'
    set -l PREVIEW_COMMAND "echo {1};echo;git log {1} --graph --color=always --format=\"%C(auto) %<(50,trunc)%s %C(green)%C(bold)%<(15,trunc)%cr% %C(blue)%<(15,trunc)%an %C(auto)%d %h\""
    set -l result (_git_fuzzy_branch_input | fzf $GIT_FZF_DEFAULT_OPTS --preview "$PREVIEW_COMMAND" --preview-window=top:85% --bind 'enter:become(echo {1})')
    echo $result
end

function git_fuzzy_checkout_branch --description 'Pick a branch via fzf, print "git checkout <name>"'
    set -l PREVIEW_COMMAND "echo git checkout {1};echo;git log {1} --graph --color=always --format=\"%C(auto) %<(50,trunc)%s %C(green)%C(bold)%<(15,trunc)%cr% %C(blue)%<(15,trunc)%an %C(auto)%d %h\""
    set -l result (_git_fuzzy_branch_input | fzf $GIT_FZF_DEFAULT_OPTS --preview "$PREVIEW_COMMAND" --preview-window=top:85% --bind 'enter:become(echo {1})')
    echo git checkout (string escape -- $result)
end

function git_fuzzy_file --description 'Pick changed files via fzf (multi-select); print paths relative to the current directory'
    set -l root (git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$root"
        echo "git_fuzzy_file: not inside a git repository" >&2
        return 1
    end

    # One "display\tpath" row per change (display = pretty_git_status line,
    # path = repo-relative path; renames reduce to their destination), so each
    # fzf match carries its own untruncated path in field 2.
    set -l rows (pretty_git_status_rows)
    test (count $rows) -gt 0; or return 0

    set -l pager cat
    command -q delta; and set pager "delta --diff-so-fancy --line-numbers"
    set -l PREVIEW_COMMAND "git -C $root diff --color=always HEAD -- {2} | $pager"

    set -l result (printf '%s\n' $rows | fzf $GIT_FZF_DEFAULT_OPTS \
        --multi --delimiter="\t" --with-nth=1 \
        --header 'enter: choose · tab: toggle-select · ctrl-a: select-all · esc/q: abort' \
        --preview "$PREVIEW_COMMAND" --preview-window=top:60% \
        --bind ctrl-a:select-all --bind 'enter:become(printf "%s\n" {+2})')

    # $result holds one REPO-relative path per line ({+2} falls back to the
    # highlighted item when nothing is multi-selected). But git commands
    # resolve pathspecs against the caller's cwd, so convert to PWD-relative:
    # paths under the cwd are shortened, everything else gets ../ prefixing.
    test -n "$result"; or return 0
    set -l prefix (git rev-parse --show-prefix 2>/dev/null)
    if test -n "$prefix"
        set -l plen (string length -- $prefix)
        set -l ups (string repeat -n (math (count (string split / -- $prefix)) - 1) "../")
        set -l out
        for p in $result
            if test "$prefix" = (string sub -l $plen -- $p)
                set out $out (string sub -s (math $plen + 1) -- $p)
            else
                set out $out "$ups$p"
            end
        end
        set result $out
    end
    echo (string escape -- $result)
end
