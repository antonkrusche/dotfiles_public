set fish_greeting

if status is-interactive
    # Commands to run in interactive sessions can go here
    fish_vi_key_bindings

    set -g fish_cursor_default block # normal/visual: steady block  (\e[2 q)
    set -g fish_cursor_insert line # insert:        steady bar    (\e[6 q)
    set -g fish_cursor_replace_one underscore # replace one:   steady under  (\e[4 q)
    set -g fish_cursor_visual block

    # Fallback workaround for terminals where the built-in cursor handling
    # misbehaves (historically Windows Terminal). Enabling it shadows the
    # built-in handler, so it must re-declare every event the built-in covers
    # (especially fish_focus_in). To force it elsewhere, either extend the
    # condition below or temporarily replace it with `if true`.
    if test "$TERM_PROGRAM" = Windows_Terminal
        function fish_vi_cursor_handle --on-variable fish_bind_mode \
            --on-event fish_postexec --on-event fish_focus_in --on-event fish_read
            switch $fish_bind_mode
                case default visual '*'
                    echo -en "\e[2 q"
                case insert
                    echo -en "\e[6 q"
                case replace_one
                    echo -en "\e[4 q"
            end
        end
    end

    # Locate this repo, resolving the symlink fish follows
    # (~/.config/fish/config.fish -> <repo>/config.fish), so the sources below
    # work no matter where the dotfiles repo is cloned.
    set -l dotfiles_dir (dirname (path resolve (status filename)))

    # Color theme (dircolors)
    source $dotfiles_dir/fish_scripts/gruvbox.fish
    # source $dotfiles_dir/fish_scripts/nord.fish

    # Init important apps
    fzf --fish | source
    zoxide init fish | source

    # Source my own scripts and utilities
    source $dotfiles_dir/fish_scripts/fuzzygrep.fish
    source $dotfiles_dir/fish_scripts/fuzzygit.fish
    source $dotfiles_dir/fish_scripts/pretty_git_status.fish
    source $dotfiles_dir/fish_scripts/pretty_git_log.fish
    source $dotfiles_dir/fish_scripts/fuzzycheatsheet.fish
    source $dotfiles_dir/fish_scripts/fzfabbr.fish

    # WSL-only helpers: prefer Windows .exe tools when working on /mnt/<drive>
    if test -n "$WSL_DISTRO_NAME"; or string match -qi '*microsoft*' -- (uname -r)
        source $dotfiles_dir/fish_scripts/wsl_alias.fish
    end

    abbr frg fuzzygrep
    abbr gst pretty_git_status
    abbr gl pretty_git_log
    abbr gfb --function git_fuzzy_branch --position anywhere
    abbr gff --function git_fuzzy_file --position anywhere

    # Open the fuzzy cheatsheet with Ctrl+a (insert and vi normal mode)
    bind --mode insert \ca fuzzy-cheat-sheet
    bind --mode default \ca fuzzy-cheat-sheet

    # ls alternative
    alias l "eza --all --icons --long --git --no-permissions --header --git-repos --color=always"

    #Lazygit
    abbr lg lazygit

    #Git
    abbr gs "git status"
    abbr gcl "git clone"
    abbr gaa "git add --all"
    abbr gap "git add --patch"
    abbr gaap "git add --all --patch"
    abbr --set-cursor gc "git commit -m \"%\""
    abbr gca "git commit --amend"
    abbr gcane "git commit --amend --no-edit"
    abbr gcb --function git_fuzzy_checkout_branch --position command

    # My own git utilities
    abbr gfl git-fuzzy-log
    abbr gfd git-fuzzy-diff HEAD

    #Neovim
    abbr v nvim
    abbr vi nvim
    abbr vim nvim
    abbr vimdiff 'nvim -d'
end

set --export EDITOR nvim

set --export FZF_ALT_C_COMMAND "fd --type directory --exclude .git --follow --hidden --color=always"
set --export FZF_DEFAULT_COMMAND "fd --type file --exclude .git --follow --hidden --color=always"
set --export FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set --export FZF_DEFAULT_OPTS "--layout=reverse --ansi"
set --export fzf_diff_highlighter delta --paging=never --width=20 --syntax-theme gruvbox-dark

starship init fish | source
