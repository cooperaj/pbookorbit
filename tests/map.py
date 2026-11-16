#!/usr/bin/env python3
"""Prints what the tests cover, as Markdown: each test file's name, the first sentence of a
QML file's opening comment, and its tests' names as sentences. Run with make test-map.

Reads the test names only; it doesn't build or run anything."""

import re
import sys
from pathlib import Path

TESTS = Path(__file__).resolve().parent
LAYERS = [
    ("Whole app", "qml/app", "tst_*.qml"),
    ("Components", "qml/components", "tst_*.qml"),
    ("Unit", "unit", "tst_*.cpp"),
]

# Names can't hold apostrophes, and a run of capitals splits into single letters
WORDS = {
    "doesnt": "doesn't", "cant": "can't", "isnt": "isn't", "whats": "what's",
    "querys": "query's", "repeaters": "repeater's",
}
PHRASES = {"a to z": "A to Z", "z to a": "Z to A"}


def sentence(name):
    words = re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z])", " ", name).lower().split()
    text = " ".join(WORDS.get(w, w) for w in words)
    for phrase, fixed in PHRASES.items():
        text = re.sub(rf"\b{phrase}\b", fixed, text)

    return text[0].upper() + text[1:]


def opening_comment(lines):
    """The first sentence of the comment block before the test case"""
    block = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("//"):
            block.append(stripped.lstrip("/ "))
        elif block:
            break

    text = " ".join(block)
    match = re.match(r"(.+?[.:])(\s|$)", text)
    return match.group(1) if match else text


def qml_file(path):
    source = path.read_text()
    name = re.search(r'^\s+name:\s*"([^"]+)"', source, re.M)
    tests = [t for t in re.findall(r"function test_(\w+)\(", source) if not t.endswith("_data")]
    return (name.group(1) if name else path.stem[4:]), opening_comment(source.splitlines()), tests


def cpp_file(path):
    source = path.read_text()
    name = re.search(r"^class Test(\w+)", source, re.M)
    slots = source.split("private slots:", 1)[-1]
    tests = [t for t in re.findall(r"^    void (\w+)\(\)", slots, re.M)
             if not t.endswith("_data") and t not in ("init", "cleanup", "initTestCase", "cleanupTestCase")]
    # Their opening comments are about Qt Test, not what's tested
    return name.group(1), "", tests


def main():
    layers = []
    for title, folder, pattern in LAYERS:
        files = []
        for path in sorted((TESTS / folder).rglob(pattern)):
            heading, about, tests = (cpp_file if path.suffix == ".cpp" else qml_file)(path)
            files.append((heading, path.relative_to(TESTS.parent), about, tests))
        layers.append((title, files))

    out = ["# Test map", "", "| Layer | Files | Tests |", "|---|---|---|"]
    for title, files in layers:
        out.append(f"| {title} | {len(files)} | {sum(len(f[3]) for f in files)} |")

    for title, files in layers:
        out += ["", f"## {title}"]
        for heading, path, about, tests in files:
            out += ["", f"### {heading} ({len(tests)})", "", f"`{path}`"]
            if about:
                out += ["", about]
            out.append("")
            out += [f"- {sentence(t)}" for t in tests]

    sys.stdout.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
