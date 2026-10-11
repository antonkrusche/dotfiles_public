#!/usr/bin/env python3
"""Extract cheatsheet entries for fuzzy-cheat-sheet from TOML files.

Usage: parse_cheatsheets.py <cheatsheet_dir> [abbr_show_file]

The optional abbr_show_file is the plain-text output of `abbr --show
--color=never` from the running shell. When given, every cheat command is
matched against the abbreviations and the ones that (roughly) expand to that
command are rendered as a highlighted "\u2192name" badge, so the cheatsheet
teaches you the abbreviation while you use it.

Writes a line protocol to stdout, consumed by the fish wrapper (TAB-separated
so the display text can contain ': ' and '|' freely):
  CMD:<ansi-formatted display>\t<raw command>\t<comma-separated abbrs>
  PROV:<name>:<list_cmd>|<extract_cmd>   one line per parameter provider
Errors are reported on stderr as "ERROR:<message>".
"""
import glob
import re
import shlex
import sys

ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
PLACEHOLDER_RE = re.compile(r"\{\{[^}]*\}\}")


def parse_abbreviations(text):
    """Parse `abbr --show --color=never` output into {name: expansion}.

    Function abbreviations are keyed by their function name (a dynamic
    expansion has no fixed text). "anywhere"-position abbreviations are
    skipped: they do not stand for a cheatsheet command.
    """
    abbrs = {}
    for raw in text.splitlines():
        line = ANSI_RE.sub("", raw).strip()
        if not line.startswith("abbr "):
            continue
        line = line.split(" # ", 1)[0]  # drop "imported from universal variable"
        try:
            tokens = shlex.split(line)
        except ValueError:
            continue
        if "--" not in tokens:
            continue
        sep = tokens.index("--")
        flags, tail = tokens[1:sep], tokens[sep + 1:]
        if not tail:
            continue
        name = tail[0]

        if "--position" in flags:
            i = flags.index("--position")
            if i + 1 < len(flags) and flags[i + 1] == "anywhere":
                continue

        if "--function" in flags:
            i = flags.index("--function")
            abbrs[name] = flags[i + 1] if i + 1 < len(flags) else ""
        else:
            abbrs[name] = " ".join(tail[1:])
    return abbrs


def normalize_tokens(command):
    """Tokenize a command, collapsing {{placeholders}} and the --set-cursor
    '%' marker into a single "{}" token."""
    command = PLACEHOLDER_RE.sub("{}", command)
    command = re.sub(r"(?<!\S)%(?!\S)", "{}", command)
    return command.split()


def commands_match(abbr_expansion, command):
    """True if the abbreviation expansion and the cheatsheet command name the
    same thing. Placeholders and a trailing --set-cursor marker are ignored,
    and a genuine prefix counts (e.g. "pretty_git_log" for
    "pretty_git_log {{branch}}")."""
    a = normalize_tokens(abbr_expansion)
    b = normalize_tokens(command)
    while a and a[-1] == "{}":
        a.pop()
    while b and b[-1] == "{}":
        b.pop()
    if not a or not b:
        return False
    return a == b or a[: min(len(a), len(b))] == b[: min(len(a), len(b))]


def find_abbrs(cmd, explicit, abbrs):
    """Return the abbreviation names to show for one entry. An explicit
    `abbr` field in the TOML wins; otherwise match the command text."""
    if explicit is not None:
        names = [explicit] if isinstance(explicit, str) else list(explicit)
        return sorted(set(names))
    return sorted(n for n, exp in abbrs.items() if commands_match(exp, cmd))


def format_badge(names, color):
    if not names:
        return ""
    # Subtle "\u2192name" marker in the accent colour from colors.toml.
    return f"\033[{color}m" + " ".join("\u2192" + n for n in names) + "\033[0m "


def main():
    import tomllib  # python 3.11+; import failures surface as "ERROR:..." below

    cheat_dir = sys.argv[1]
    abbr_file = sys.argv[2] if len(sys.argv) > 2 else None

    abbrs = {}
    if abbr_file:
        try:
            with open(abbr_file, encoding="utf-8") as f:
                abbrs = parse_abbreviations(f.read())
        except OSError:
            pass

    # Load the palette if colors.toml exists; fall back to built-in defaults
    # so the sheet keeps working without the file. [meta].badge/dim are global,
    # [sections] maps a section to an SGR colour, [sections].default is the
    # fallback for unlisted sections.
    colors, meta = {}, {}
    try:
        with open(f"{cheat_dir}/colors.toml", "rb") as f:
            palette = tomllib.load(f)
        colors = palette.get("sections", {})
        meta = palette.get("meta", {})
    except FileNotFoundError:
        pass
    default_color = str(colors.get("default", "36"))
    badge_color = str(meta.get("badge", "38;5;208"))
    dim_color = str(meta.get("dim", "90"))

    file_paths = [f for f in glob.glob(cheat_dir + "/*.toml") if "colors.toml" not in f]
    for file_path in file_paths:
        with open(file_path, "rb") as f:
            data = tomllib.load(f)

        # Print providers first, prefixed with "PROV:"
        for name, cmd in data.get("providers", {}).items():
            print(f"PROV:{name}:{cmd}")

        # Print commands, prefixed with "CMD:"
        for section, content in data.items():
            if section == "providers":
                continue
            # Colour for this section, falling back to [sections].default.
            color_code = str(colors.get(section, default_color))
            for name, val in content.items():
                if isinstance(val, dict):
                    cmd = val.get("cmd", "")
                    kw = " ".join(val.get("keywords", []))
                    explicit = val.get("abbr")
                else:
                    cmd = val
                    kw = ""
                    explicit = None

                names = find_abbrs(cmd, explicit, abbrs)
                badge = format_badge(names, badge_color)

                # All colour codes come from colors.toml so they can follow the
                # terminal theme. Badge sits right after the command so it is
                # visible even on long lines. Tabs separate display / raw cmd /
                # abbr names for the fish wrapper; the display itself contains
                # none.
                display = (
                    f"\033[{color_code}m[{section}]\033[0m {name}: "
                    f"\033[{color_code}m{cmd}\033[0m {badge}"
                    f"\033[{dim_color}m|\033[0m {kw}"
                )
                print(f"CMD:{display}\t{cmd}\t{','.join(names)}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"ERROR:{e}", file=sys.stderr)
        raise SystemExit(1)
