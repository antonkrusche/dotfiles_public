#!/usr/bin/env python3
"""pretty_git_status — `git status` with aligned, exact per-file +N/-N counts.

Renders `git status --porcelain -b` (machine format, colors re-applied by us)
with a right-hand column of exact added/deleted line counts from
`git diff --numstat HEAD`. Paths are middle-elided, keeping the filename and
as many directory components as fit. Untracked files get no count column.
"""
import re
import shutil
import subprocess

def c(code, s):
    return f"\x1b[{code}m{s}\x1b[0m"

def git(*args):
    r = subprocess.run(["git", "-c", "core.quotePath=false", *args],
                       capture_output=True, text=True, errors="replace")
    return r.stdout if r.returncode == 0 else None

def numstat():
    """path-after-rename -> (adds, dels); '-' means binary."""
    out = git("diff", "--numstat", "HEAD")
    if out is None:          # e.g. repository without any commit yet
        return {}
    stats = {}
    for line in out.splitlines():
        f = line.split("\t")
        if len(f) >= 3:                       # unmerged lines have no path
            # numstat renames: "old => new" or "dir/{old => new}/suffix"
            p = re.sub(r"\{[^}]*=>\s*([^}]*)\}", r"\1", "\t".join(f[2:]))
            p = re.sub(r"^\s*.*\s=>\s*", "", p)
            stats[p.strip('"')] = (f[0], f[1])
    return stats

def shorten_path(path, budget):
    """Middle-truncate to budget chars, keeping filename + nearest dirs."""
    if len(path) <= budget:
        return path
    if budget <= 1:
        return path[:budget]
    parts = path.split("/")
    last, lastlen = parts[-1], len(parts[-1])
    if lastlen + 2 >= budget:                 # filename (+ '…/') doesn't fit
        keep = budget - 1
        head = keep // 2
        return last[:head] + "…" + last[lastlen - (keep - head):]
    room, back_from = budget - lastlen - 2, len(parts) - 1
    for i in range(len(parts) - 2, -1, -1):   # nearest directories first
        if len(parts[i]) + 1 > room:
            break
        back_from, room = i, room - len(parts[i]) - 1
    front_to = 0
    for i in range(0, back_from):             # spend leftovers on leading dirs
        if len(parts[i]) + 1 > room:
            break
        front_to, room = i + 1, room - len(parts[i]) - 1
    front = "/".join(parts[:front_to]) + "/" if front_to else ""
    back = "/".join(parts[back_from:len(parts) - 1]) + "/" if back_from < len(parts) - 1 else ""
    return f"{front}…/{back}{last}"

def shorten(path, budget):
    """Shorten a status path, which may be a rename 'old -> new'."""
    if " -> " not in path:
        return shorten_path(path, budget)
    old, new = path.split(" -> ", 1)
    avail = budget - 4                        # ' -> ' separator
    if avail < 2:
        return shorten_path(path, budget)
    if len(old) + len(new) <= avail:
        return f"{old} -> {new}"
    nb = min(avail * 6 // 10, len(new))       # new side gets the larger share
    ob = avail - nb
    if len(old) < ob:
        nb, ob = avail - len(old), len(old)
    return shorten_path(old, ob) + " -> " + shorten_path(new, nb)

def xy_prefix(xy):
    if xy == "??":
        return c(31, xy)
    x = c(32, xy[0]) if xy[0] not in " ?" else xy[0]
    y = c(31, xy[1]) if xy[1] not in " ?" else xy[1]
    return x + y

def count_column(add, dele, add_w, del_w):
    if add == "-":
        return " " * (add_w - 3) + c(33, "bin") + " " * (del_w + 1)
    tok_del = c(31, f"-{dele}") if dele not in ("0", "-") else ""
    pad_del = del_w - (len(dele) + 1 if tok_del else 0)
    return " " * (add_w - len(add) - 1) + c(32, f"+{add}") + " " + " " * pad_del + tok_del

def main():
    cols = shutil.get_terminal_size().columns          # COLUMNS env, ioctl, else 80
    status = git("status", "--porcelain", "-b")
    stats = numstat()
    if status is None:
        return 1                                       # not a git repository
    rows = []
    for line in status.splitlines():
        if line.startswith("##"):
            rows.append((None, line[3:].strip('"'), "", ""))
        else:
            xy, path = line[:2], line[3:].strip('"')
            add, dele = stats.get(path.split(" -> ")[-1], ("", ""))
            rows.append((xy, path, add, dele))

    add_w = del_w = left_max = 0
    for xy, path, add, dele in rows:
        if not add:
            continue
        add_w = max(add_w, 3 if add == "-" else len(add) + 1)
        if dele not in ("0", "-"):
            del_w = max(del_w, len(dele) + 1)
        left_max = max(left_max, len(xy) + 1 + len(path))

    statw = add_w + 1 + del_w
    left_width = max(4, min(left_max, max(8, cols - 3 - statw)))

    for xy, path, add, dele in rows:
        if xy is None:
            print(f"## {c(32, path)}")
            continue
        budget = max(1, (left_width if add else cols) - 3)
        shown = shorten(path, budget)
        left = xy_prefix(xy) + " " + shown
        if add:
            vis = len(xy) + 1 + len(shown)
            pad = max(0, left_width - vis)
            print(f"{left}{' ' * pad} | {count_column(add, dele, add_w, del_w)}")
        else:
            print(left)

    summary = (git("diff", "--shortstat", "HEAD") or "").strip()
    if summary:
        print(f"\x1b[2m{summary}\x1b[22m")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())