#!/usr/bin/env python3
"""Extract cheatsheet entries for fuzzy-cheat-sheet from TOML files.

Usage: parse_cheatsheets.py <cheatsheet_dir>

Writes a line protocol to stdout, consumed by the fish wrapper:
  CMD:<ansi-formatted entry>             one line per cheat command
  PROV:<name>:<list_cmd>|<extract_cmd>   one line per parameter provider
Errors are reported on stderr as "ERROR:<message>".
"""
import glob
import sys


def main():
    import tomllib  # python 3.11+; import failures surface as "ERROR:..." below

    cheat_dir = sys.argv[1]

    # Load section colors if colors.toml exists
    colors = {}
    try:
        with open(f"{cheat_dir}/colors.toml", "rb") as f:
            colors = tomllib.load(f).get("sections", {})
    except FileNotFoundError:
        pass

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
            # Get color for this section, default to 36 (Cyan)
            color_code = colors.get(section, "36")
            for name, val in content.items():
                if isinstance(val, dict):
                    cmd = val.get("cmd", "")
                    kw = " ".join(val.get("keywords", []))
                else:
                    cmd = val
                    kw = ""
                # \033[{color_code}m = Section Color, \033[90m = Grey, \033[0m = Reset
                print(f"CMD:\033[{color_code}m[{section}]\033[0m {name}: "
                      f"\033[{color_code}m{cmd}\033[0m \033[90m|\033[0m {kw}")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"ERROR:{e}", file=sys.stderr)
        raise SystemExit(1)