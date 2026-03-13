#!/usr/bin/env python3
"""
matlab_arguments_compat.py

Reversible disabling/enabling of MATLAB arguments blocks for pre-R2022a compatibility.

Disable:
  - Finds uncommented `arguments ... end` blocks
  - Comments each line in that block by inserting a marker:
        <indent>%<ARGCOMPAT2022A> <rest_of_line>

Enable:
  - Uncomments only lines with the marker (exactly reversible)
  - Does NOT touch other commented code or comments inside the block

Also prints per-file logs and optional signature/arguments-count warnings.

Notes:
- This is a robust heuristic parser, not a full MATLAB parser.
- It avoids matching "arguments" inside other words, strings, comments, or %{ %} blocks (best-effort).
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
import re
import sys
from pathlib import Path

MARKER = "%<ARGCOMPAT2022A> "  # Marker inserted after indentation

# %% Utilities

def _is_line_commented(line: str) -> bool:
    """Return True when a line is a MATLAB comment.

    Args:
        line: Line to inspect.

    Returns:
        True if the line starts with `%` after optional whitespace.
    """
    return bool(re.match(r"^\s*%", line))


def _strip_inline_comment_best_effort(line: str) -> str:
    """Strip inline comments while preserving string literals.

    Best-effort: removes inline comments starting with `%` that are not inside
    single- or double-quoted strings.

    Args:
        line: Line to process.

    Returns:
        Line with inline comments removed, preserving newline stripping.
    """
    out = []
    in_sq = False
    in_dq = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "'" and not in_dq:
            # MATLAB '' inside single quotes escapes; handle minimally
            if in_sq and i + 1 < len(line) and line[i + 1] == "'":
                out.append("''")
                i += 2
                continue
            in_sq = not in_sq
            out.append(ch)
            i += 1
            continue
        if ch == '"' and not in_sq:
            in_dq = not in_dq
            out.append(ch)
            i += 1
            continue
        if ch == "%" and not in_sq and not in_dq:
            break
        out.append(ch)
        i += 1
    return "".join(out).rstrip("\n")


def _split_args_list(arglist: str) -> list[str]:
    """Split a comma-separated argument list while respecting nesting and strings.

    Args:
        arglist: Raw argument list from within parentheses.

    Returns:
        List of argument items with whitespace trimmed.
    """
    items = []
    cur = []
    depth = 0
    in_sq = False
    in_dq = False
    i = 0
    while i < len(arglist):
        ch = arglist[i]
        if ch == "'" and not in_dq:
            if in_sq and i + 1 < len(arglist) and arglist[i + 1] == "'":
                cur.append("''")
                i += 2
                continue
            in_sq = not in_sq
            cur.append(ch)
            i += 1
            continue
        if ch == '"' and not in_sq:
            in_dq = not in_dq
            cur.append(ch)
            i += 1
            continue
        if not in_sq and not in_dq:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth = max(0, depth - 1)
            elif ch == "," and depth == 0:
                items.append("".join(cur).strip())
                cur = []
                i += 1
                continue
        cur.append(ch)
        i += 1
    tail = "".join(cur).strip()
    if tail:
        items.append(tail)
    return [x for x in items if x]


# %% Signature collection and parsing
_FUNC_LINE_RE = re.compile(r"^\s*function\b")

def _collect_function_signature(lines: list[str], i0: int) -> tuple[str, int]:
    """Collect a MATLAB function signature across continuation lines.

    Best-effort: joins lines ending in `...` and does not parse nested bodies.

    Args:
        lines: Full file contents split into lines.
        i0: Starting index for the function signature line.

    Returns:
        Tuple of the signature string and the last line index used.
    """
    sig_parts = []
    i = i0
    while i < len(lines):
        line = lines[i]
        if _is_line_commented(line):
            break
        txt = _strip_inline_comment_best_effort(line).rstrip()
        sig_parts.append(txt)
        if txt.endswith("..."):
            i += 1
            continue
        break
    sig = " ".join([p[:-3].rstrip() if p.endswith("...") else p for p in sig_parts]).strip()
    return sig, i

def _parse_signature_inputs(sig: str) -> list[str]:
    """Extract input argument names from a function signature.

    Args:
        sig: Function signature line as a string.

    Returns:
        List of input argument names, best-effort.
    """
    if not sig.strip().startswith("function"):
        return []

    # Remove leading 'function'
    s = sig.strip()[len("function"):].strip()

    # Find first '(' that likely starts the input list
    # We assume inputs appear as name(...). This is heuristic.
    idx = s.find("(")
    if idx < 0:
        return []

    # Find matching ')'
    depth = 0
    in_sq = False
    in_dq = False
    start = idx + 1
    end = None
    for j in range(idx, len(s)):
        ch = s[j]
        if ch == "'" and not in_dq:
            in_sq = not in_sq
        elif ch == '"' and not in_sq:
            in_dq = not in_dq
        elif not in_sq and not in_dq:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    end = j
                    break
    if end is None:
        return []

    arglist = s[start:end].strip()
    if not arglist:
        return []

    items = _split_args_list(arglist)

    # Normalize items (remove default assignments, size specs are not in signature anyway)
    # Filter out ~
    out = []
    for it in items:
        it = it.strip()
        if not it or it == "~":
            continue
        # signature args could be "varargin" etc; keep as-is
        out.append(it)
    return out


# %% Arguments block parsing
_ARGS_START_RE = re.compile(r"^\s*arguments\b(\s*\(.*\))?\s*$")
_END_LINE_RE = re.compile(r"^\s*end\b(\s*%.*)?\s*$")

@dataclass
class ArgumentsBlockInfo:
    """Metadata for a MATLAB arguments block.

    Attributes:
        start_line: Zero-based line index for the `arguments` line.
        end_line: Zero-based line index for the `end` line.
        already_commented: Whether the block was already commented.
        modified: Whether the block was modified by this run.
    """
    start_line: int
    end_line: int
    already_commented: bool
    modified: bool = False

def _line_is_arguments_start(line: str, in_block_comment: bool) -> bool:
    """Return True if a line starts an arguments block.

    Args:
        line: Line to inspect.
        in_block_comment: Whether the parser is inside a `%{ %}` comment.

    Returns:
        True if the line is a valid `arguments` start line.
    """
    if in_block_comment:
        return False
    if _is_line_commented(line):
        return False
    txt = _strip_inline_comment_best_effort(line).strip()
    return bool(_ARGS_START_RE.match(txt))

def _find_arguments_blocks(lines: list[str]) -> list[ArgumentsBlockInfo]:
    """Find uncommented MATLAB arguments blocks in a list of lines.

    Args:
        lines: File contents split into lines.

    Returns:
        List of arguments block metadata entries.
    """
    blocks: list[ArgumentsBlockInfo] = []
    in_block_comment = False
    i = 0
    while i < len(lines):
        line = lines[i]

        # Track %{ %} block comments (best-effort)
        if not _is_line_commented(line) and "%{" in line:
            in_block_comment = True
        if in_block_comment:
            if "%}" in line:
                in_block_comment = False
            i += 1
            continue

        # Detect arguments start (uncommented only)
        if _line_is_arguments_start(line, in_block_comment=False):
            # Now find the corresponding end line.
            j = i + 1
            while j < len(lines):
                l2 = lines[j]
                # stop if we enter a %{ %} block comment unexpectedly
                if not _is_line_commented(l2) and "%{" in l2:
                    # Still, treat it as inside arguments; arguments blocks typically won't contain this.
                    # We'll just skip until %} and continue searching for 'end'.
                    k = j + 1
                    while k < len(lines) and "%}" not in lines[k]:
                        k += 1
                    j = min(k + 1, len(lines))
                    continue

                if not _is_line_commented(l2):
                    txt2 = _strip_inline_comment_best_effort(l2).strip()
                    if _END_LINE_RE.match(txt2):
                        blocks.append(ArgumentsBlockInfo(start_line=i, end_line=j, already_commented=False))
                        i = j + 1
                        break
                j += 1
            else:
                # no end found; ignore
                i += 1
            continue

        i += 1

    return blocks


def _comment_with_marker(line: str) -> str:
    """Insert the compatibility marker after indentation.

    Args:
        line: Line to comment.

    Returns:
        Commented line with the marker, or the original line if already commented.
    """
    if _is_line_commented(line):
        return line
    m = re.match(r"^(\s*)(.*)$", line)
    assert m is not None
    indent, rest = m.group(1), m.group(2)
    return f"{indent}{MARKER}{rest}"


def _uncomment_marker(line: str) -> str:
    """Remove the compatibility marker if present after indentation.

    Args:
        line: Line to process.

    Returns:
        Line with marker removed when present, otherwise the original line.
    """
    m = re.match(r"^(\s*)%<ARGCOMPAT2022A>\s?(.*)$", line)
    if not m:
        return line
    indent, rest = m.group(1), m.group(2)
    return f"{indent}{rest}"


def _block_is_already_commented(lines: list[str], start_line: int) -> bool:
    """Check whether an arguments block is already commented.

    Args:
        lines: File contents split into lines.
        start_line: Line index of the `arguments` keyword.

    Returns:
        True if the arguments start line is commented.
    """
    return _is_line_commented(lines[start_line])


def _disable_blocks(lines: list[str], blocks: list[ArgumentsBlockInfo]) -> tuple[list[str], int]:
    """Disable arguments blocks by inserting the compatibility marker.

    Args:
        lines: File contents split into lines.
        blocks: Arguments block metadata.

    Returns:
        Tuple of the updated lines and the number of modified blocks.
    """
    new_lines = lines[:]
    modified_blocks = 0
    for b in blocks:
        if _block_is_already_commented(new_lines, b.start_line):
            # as requested: pattern detected but already commented -> do nothing
            continue
        for k in range(b.start_line, b.end_line + 1):
            # Only comment lines not already commented; do not double-apply marker
            if re.match(r"^\s*%<ARGCOMPAT2022A>", new_lines[k]):
                continue
            if _is_line_commented(new_lines[k]):
                continue
            new_lines[k] = _comment_with_marker(new_lines[k])
        modified_blocks += 1
    return new_lines, modified_blocks


def _enable_blocks(lines: list[str]) -> tuple[list[str], int]:
    """Enable arguments blocks by removing the compatibility marker.

    Args:
        lines: File contents split into lines.

    Returns:
        Tuple of updated lines and the number of marker lines uncommented.
    """
    new_lines = lines[:]
    changed = 0
    for i, ln in enumerate(new_lines):
        if re.match(r"^\s*%<ARGCOMPAT2022A>", ln):
            new_lines[i] = _uncomment_marker(ln)
            changed += 1
    return new_lines, changed


# ----------------------- arguments count cross-check -----------------------

def _collect_arguments_entries(lines: list[str], b: ArgumentsBlockInfo) -> tuple[int, int, int]:
    """Count positional and keyword entries within an arguments block.

    Heuristics:
        - Join continuation lines ending with `...`.
        - Ignore blank lines and pure comments.
        - For each statement, use the first token:
          - If token contains `.`, the root before `.` is a keyword group.
          - If the statement contains `=`, treat as a keyword singleton.
          - Otherwise, treat as positional.

    Args:
        lines: File contents split into lines.
        b: Arguments block metadata.

    Returns:
        Tuple of positional count, keyword group count, and total effective count.
    """
    stmts: list[str] = []
    cur = ""

    for i in range(b.start_line + 1, b.end_line):  # between arguments and end
        ln = lines[i]

        # If block is disabled with marker, lines may be prefixed; for counting, strip marker if present
        ln2 = _uncomment_marker(ln)

        if _is_line_commented(ln2):
            continue
        txt = _strip_inline_comment_best_effort(ln2).strip()
        if not txt:
            continue

        if txt.endswith("..."):
            cur += " " + txt[:-3].rstrip()
            continue
        else:
            cur += " " + txt
            stmts.append(cur.strip())
            cur = ""

    if cur.strip():
        stmts.append(cur.strip())

    positional = 0
    keyword_roots = set()

    for st in stmts:
        # First token: up to first whitespace or '(' or '='
        m = re.match(r"^([A-Za-z]\w*(?:\.[A-Za-z]\w*)?)", st)
        if not m:
            continue
        tok = m.group(1)

        if "." in tok:
            root = tok.split(".", 1)[0]
            keyword_roots.add(root)
        else:
            if "=" in st:
                # likely name-value singleton
                keyword_roots.add(tok)
            else:
                positional += 1

    kw = len(keyword_roots)
    return positional, kw, positional + kw


# ----------------------- main processing -----------------------

@dataclass
class FileReport:
    """Summary of processing results for a file.

    Attributes:
        path: File path that was processed.
        changed: Whether any changes were made.
        blocks_found: Number of arguments blocks found.
        blocks_modified: Number of arguments blocks modified.
        enable_lines_uncommented: Number of lines uncommented in enable mode.
        warnings: Collected warning messages.
    """
    path: Path
    changed: bool
    blocks_found: int
    blocks_modified: int
    enable_lines_uncommented: int
    warnings: list[str]


def _process_file(path: Path, mode: str, do_check: bool, dry_run: bool, backup: bool) -> FileReport:
    """Process a single MATLAB file for arguments block updates.

    Args:
        path: Path to the file to process.
        mode: Either `disable` or `enable`.
        do_check: Whether to perform signature/arguments cross-checks.
        dry_run: Whether to skip writing changes to disk.
        backup: Whether to write a `.bak` copy on the first change.

    Returns:
        FileReport summarizing the actions taken.
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines(keepends=True)

    warnings: list[str] = []

    # Optional signature extraction (best-effort: first function in file)
    sig_inputs: list[str] = []
    for i, ln in enumerate(lines):
        if _FUNC_LINE_RE.match(ln) and not _is_line_commented(ln):
            sig, _ = _collect_function_signature(lines, i)
            sig_inputs = _parse_signature_inputs(sig)
            break

    blocks = _find_arguments_blocks(lines)

    blocks_modified = 0
    enable_uncommented = 0

    if mode == "disable":
        new_lines, blocks_modified = _disable_blocks(lines, blocks)
    elif mode == "enable":
        new_lines, enable_uncommented = _enable_blocks(lines)
    else:
        raise ValueError(f"Unknown mode: {mode}")

    changed = (new_lines != lines)

    # Cross-check counts
    if do_check and blocks:
        # Sum over blocks (common case is 1 per function file)
        pos_sum = 0
        kw_sum = 0
        eff_sum = 0
        for b in blocks:
            pos, kw, eff = _collect_arguments_entries(lines, b)
            pos_sum += pos
            kw_sum += kw
            eff_sum += eff

        if sig_inputs:
            sig_n = len(sig_inputs)
            # Heuristic handling of varargin: if signature contains varargin, allow extra keyword groups
            has_varargin = any(x.strip() == "varargin" for x in sig_inputs)
            if not has_varargin and sig_n != eff_sum:
                warnings.append(
                    f"Signature inputs={sig_n} but arguments effective entries={eff_sum} (pos={pos_sum}, kwGroups={kw_sum})."
                )
            if has_varargin and sig_n > eff_sum:
                warnings.append(
                    f"Signature includes varargin; signature inputs={sig_n} > arguments effective entries={eff_sum} (pos={pos_sum}, kwGroups={kw_sum})."
                )
        else:
            warnings.append("Could not parse function signature (skipped signature/arguments cross-check).")

    # Write back
    if changed and not dry_run:
        if backup:
            bak = path.with_suffix(path.suffix + ".bak")
            if not bak.exists():
                bak.write_text(text, encoding="utf-8")
        path.write_text("".join(new_lines), encoding="utf-8")

    return FileReport(
        path=path,
        changed=changed,
        blocks_found=len(blocks),
        blocks_modified=blocks_modified,
        enable_lines_uncommented=enable_uncommented,
        warnings=warnings,
    )


def _iter_m_files(root: Path) -> list[Path]:
    """Recursively enumerate MATLAB `.m` files under a root directory.

    Args:
        root: Root directory to scan.

    Returns:
        List of `.m` file paths found under the root.
    """
    out = []
    for p in root.rglob("*.m"):
        # skip obvious vendored/hidden folders if desired (customize)
        if any(part.startswith(".") for part in p.parts):
            continue
        out.append(p)
    return out


def main() -> int:
    """Run the command-line interface for arguments block updates.

    Returns:
        Exit code for the command.
    """
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True, help="Root folder to scan")
    ap.add_argument("--mode", required=True, choices=["disable", "enable"], help="disable=comment arguments blocks, enable=restore")
    ap.add_argument("--dry-run", action="store_true", help="Do not modify files, only report")
    ap.add_argument("--backup", action="store_true", help="Create .bak once per modified file")
    ap.add_argument("--check", action="store_true", help="Cross-check signature vs arguments counts (heuristic)")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"[ERR] Root does not exist: {root}", file=sys.stderr)
        return 2

    mfiles = _iter_m_files(root)
    print(f"[INFO] Found {len(mfiles)} .m files under {root}")

    changed_files = 0
    total_blocks = 0
    total_blocks_modified = 0
    total_uncommented = 0
    total_warnings = 0

    for p in mfiles:
        rep = _process_file(
            path=p,
            mode=args.mode,
            do_check=args.check,
            dry_run=args.dry_run,
            backup=args.backup,
        )
        total_blocks += rep.blocks_found
        total_blocks_modified += rep.blocks_modified
        total_uncommented += rep.enable_lines_uncommented

        if rep.changed:
            changed_files += 1
            if args.mode == "disable":
                print(f"[MOD] {rep.path} | blocks_found={rep.blocks_found} blocks_modified={rep.blocks_modified}")
            else:
                print(f"[MOD] {rep.path} | marker_lines_uncommented={rep.enable_lines_uncommented}")
        else:
            # keep logs readable; still show if it contains warnings
            if rep.warnings:
                print(f"[CHK] {rep.path} | no change")

        for w in rep.warnings:
            total_warnings += 1
            print(f"  [WARN] {w}")

    print(f"[INFO] Mode={args.mode} dry_run={args.dry_run} backup={args.backup} check={args.check}")
    print(f"[INFO] Files changed: {changed_files}/{len(mfiles)}")
    print(f"[INFO] Arguments blocks found: {total_blocks}")
    if args.mode == "disable":
        print(f"[INFO] Arguments blocks modified: {total_blocks_modified}")
    else:
        print(f"[INFO] Marker lines uncommented: {total_uncommented}")
    print(f"[INFO] Warnings: {total_warnings}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
