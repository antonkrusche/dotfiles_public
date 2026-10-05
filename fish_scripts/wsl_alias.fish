#!/usr/bin/env fish
#
# WSL interop: prefer the Windows build of file-system heavy tools whenever the
# work tree lives on a Windows drive (/mnt/<letter>).
#
# Why EXECUTABLE SHIMS ON PATH instead of fish functions:
# fish functions only exist inside the fish process. starship, neovim plugins,
# lazygit, python helpers and plain shell scripts all exec `git`/`rg`/... on
# their own and silently bypassed the old function wrappers - that is what made
# pretty_git_status print nothing on Windows-mounted repositories (python ran
# the Linux git, which failed with a swallowed "dubious ownership" error), and
# it is why a git-driven prompt in a 100k LOC repository on /mnt could take
# minutes. A directory prepended to PATH (with `fish_add_path`) is inherited by
# every child process, so one decision point covers the whole toolchain.
#
# The shims live in <repo>/bin/wsl:
#   wsl-exec   generic dispatcher, symlinked by the simple tools (rg, fd,
#              lazygit): runs `<tool>.exe` on /mnt/<letter>, the Linux binary
#              everywhere else
#   git        dedicated shim: routes expensive work-tree scans to git.exe and
#              path-emitting queries (rev-parse) to Linux git, translates
#              -C/--git-dir/--work-tree arguments, see its header
#
# Tool policy (keep the Linux build!): fzf (it launches the previews/commands,
# which must stay in the Linux/fish world), zoxide (the Windows build keeps a
# separate database), eza (listing one directory is not the bottleneck),
# nvim (its git plugins consume /mnt/... paths, which the git shim provides).
#
# Only this file is sourced from config.fish, and only on WSL.

# --prepend is the default; --move makes an already-present entry land in
# front again after edits; --path keeps it in PATH only for the current
# session (no universal variable), so it never outlives this config.
fish_add_path --global --path --move "$dotfiles_dir/bin/wsl"