#!/usr/bin/env python3
"""Collect player-facing strings into translations/strings.csv (keys are the English text).

Run from the project root. Existing translations in other columns are kept.
The same patterns are checked by tests/localisation.gd, so CI fails when a new
UI string is not in the table.
"""
import csv, re, pathlib

PATTERNS = [
    r'(?:button|make_button)\([^"\n]*"([^"]+)"',
    r'add_check\("([^"]+)"\)',
    r'add_slider\("([^"]+)"',
    r'make_label\("([^"]+)"\)',
    r'add_item\("([^"]+)"\)',
    r'\.text = "([^"%]+)"(?!\.)',
    r'mission_log\.add\("[^"]+", "([^"]+)"',
    r'\["t_\w+", "([^"]+)"\]',
    r'"(?:title|brief)": "([^"]+)"',
    r'tr\("([^"]+)"\)',
]
SOURCES = ["mission.gd", "scope_overlay.gd", "scenes", "autoload"]

def collect(root: pathlib.Path) -> list[str]:
    found = []
    files = []
    for source in SOURCES:
        path = root / source
        files += [path] if path.is_file() else sorted(path.rglob("*.gd"))
    for path in files:
        text = path.read_text()
        for pattern in PATTERNS:
            for match in re.findall(pattern, text):
                if match.strip() and match not in found:
                    found.append(match)
    return found

def main() -> None:
    root = pathlib.Path(".")
    target = root / "translations" / "strings.csv"
    target.parent.mkdir(exist_ok=True)
    rows = {}
    header = ["keys", "en"]
    if target.exists():
        with target.open(newline="") as f:
            reader = csv.reader(f)
            header = next(reader)
            for row in reader:
                rows[row[0]] = row
    for key in collect(root):
        if key not in rows:
            rows[key] = [key, key] + [""] * (len(header) - 2)
    with target.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for key in sorted(rows):
            writer.writerow(rows[key])
    print(f"{len(rows)} strings in {target}")

if __name__ == "__main__":
    main()
