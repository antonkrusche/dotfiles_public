# WSL interop helpers.
#
# When the current directory lives on a Windows drive mounted under
# /mnt/<letter> (C:, D:, ...), prefer the Windows .exe: it accesses the
# filesystem natively instead of through WSL's slow drvfs/9p layer.
# Everywhere else, use the normal Linux binary.
#
# If the Windows tool is not installed, warn once per session and fall back
# to the Linux binary, so it is obvious which tools still need installing on
# the Windows side.
#
# Caveat: WSL translates the working directory but not command arguments, so
# the .exe works with relative paths only -- pass absolute paths to the Linux
# binary instead.

function __wsl_on_windows_drive
    string match -q -r '^/mnt/[a-zA-Z](/|$)' -- (pwd -P)
end

function __wsl_exec --argument-names cmd
    set -l args $argv[2..-1]

    if __wsl_on_windows_drive
        if command -sq "$cmd.exe"
            command "$cmd.exe" $args
            return
        end

        # Warn once per session for each missing Windows tool.
        if not contains -- $cmd $__wsl_missing_exe
            set -ga __wsl_missing_exe $cmd
            echo "wsl_alias: '$cmd.exe' not found on Windows; using Linux '$cmd' instead." >&2
        end
    end

    command $cmd $args
end

function git --wraps git
    __wsl_exec git $argv
end

function fzf --wraps fzf
    __wsl_exec fzf $argv
end

function nvim --wraps nvim
    __wsl_exec nvim $argv
end

function lazygit --wraps lazygit
    __wsl_exec lazygit $argv
end

function rg --wraps rg
    __wsl_exec rg $argv
end

function fd --wraps fd
    __wsl_exec fd $argv
end

function zoxide --wraps zoxide
    __wsl_exec zoxide $argv
end

function eza --wraps eza
    __wsl_exec eza $argv
end
