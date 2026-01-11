#!/usr/bin/env python3
"""
update_arguments_codeblocks.py

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
import re
import sys
from pathlib import Path

MARKER = "%<ARGCOMPAT2022A> "  # Marker inserted after indentation

# %% Utilities
def _is_line_commented(line_text: str) -> bool:
    """Return True when a line is a MATLAB comment.

    Args:
        line_text: Line to inspect.

    Returns:
        True if the line starts with `%` after optional whitespace.
    """
    return bool(re.match(r"^\s*%", line_text))


def _strip_inline_comment_best_effort(line_text: str) -> str:
    """Strip inline comments while preserving string literals.

    Best-effort: removes inline comments starting with `%` that are not inside
    single- or double-quoted strings.

    Args:
        line_text: Line to process.

    Returns:
        Line with inline comments removed, preserving newline stripping.
    """
    # Walk the line character-by-character so we can stop at % outside strings.
    characters = []
    in_single_quotes = False
    in_double_quotes = False
    index = 0
    while index < len(line_text):
        char = line_text[index]
        # Handle single quote: toggle single-quote state if not inside double quotes.
        if char == "'" and not in_double_quotes:
            # MATLAB uses '' to escape a single quote inside single-quoted strings.
            if in_single_quotes and index + 1 < len(line_text) and line_text[index + 1] == "'":
                characters.append("''")
                index += 2
                continue
            in_single_quotes = not in_single_quotes
            characters.append(char)
            index += 1
            continue
        # Handle double quote: toggle double-quote state if not inside single quotes.
        if char == '"' and not in_single_quotes:
            in_double_quotes = not in_double_quotes
            characters.append(char)
            index += 1
            continue
        # Handle percent sign: start of inline comment if not inside any string.
        if char == "%" and not in_single_quotes and not in_double_quotes:
            break
        characters.append(char)
        index += 1
    # Keep original line ending handling consistent with splitlines(keepends=True).
    return "".join(characters).rstrip("\n")


def _split_args_list(argument_list_text: str) -> list[str]:
    """Split a comma-separated argument list while respecting nesting and strings.

    Args:
        argument_list_text: Raw argument list from within parentheses.

    Returns:
        List of argument items with whitespace trimmed.
    """
    # Split on commas only when not nested in parentheses or inside strings.
    argument_items = []
    current_item_chars = []
    paren_depth = 0
    in_single_quotes = False
    in_double_quotes = False
    index = 0
    while index < len(argument_list_text):
        char = argument_list_text[index]
        if char == "'" and not in_double_quotes:
            if in_single_quotes and index + 1 < len(argument_list_text) and argument_list_text[index + 1] == "'":
                current_item_chars.append("''")
                index += 2
                continue
            in_single_quotes = not in_single_quotes
            current_item_chars.append(char)
            index += 1
            continue
        if char == '"' and not in_single_quotes:
            in_double_quotes = not in_double_quotes
            current_item_chars.append(char)
            index += 1
            continue
        if not in_single_quotes and not in_double_quotes:
            if char == "(":
                paren_depth += 1
            elif char == ")":
                paren_depth = max(0, paren_depth - 1)
            elif char == "," and paren_depth == 0:
                argument_items.append("".join(current_item_chars).strip())
                current_item_chars = []
                index += 1
                continue
        current_item_chars.append(char)
        index += 1
    tail_item = "".join(current_item_chars).strip()
    if tail_item:
        argument_items.append(tail_item)
    # Filter out empty items caused by extra commas or whitespace.
    return [item for item in argument_items if item]


# %% Signature collection and parsing
_FUNC_LINE_RE = re.compile(r"^\s*function\b")

def _collect_function_signature(file_lines: list[str], start_line_index: int) -> tuple[str, int]:
    """Collect a MATLAB function signature across continuation lines.

    Best-effort: joins lines ending in `...` and does not parse nested bodies.

    Args:
        file_lines: Full file contents split into lines.
        start_line_index: Starting index for the function signature line.

    Returns:
        Tuple of the signature string and the last line index used.
    """
    # Join multiline signatures (continuations marked with "...").
    signature_parts = []
    line_index = start_line_index
    while line_index < len(file_lines):
        current_line = file_lines[line_index]
        if _is_line_commented(current_line):
            break
        stripped_line = _strip_inline_comment_best_effort(current_line).rstrip()
        signature_parts.append(stripped_line)
        if stripped_line.endswith("..."):
            line_index += 1
            continue
        break
    signature_line = " ".join(
        [part[:-3].rstrip() if part.endswith("...") else part for part in signature_parts]
    ).strip()
    return signature_line, line_index

def _parse_signature_inputs(signature_line: str) -> list[str]:
    """Extract input argument names from a function signature.

    Args:
        signature_line: Function signature line as a string.

    Returns:
        List of input argument names, best-effort.
    """
    if not signature_line.strip().startswith("function"):
        return []

    # Remove leading 'function'
    signature_body = signature_line.strip()[len("function"):].strip()

    # Find first '(' that likely starts the input list
    # We assume inputs appear as name(...). This is heuristic.
    open_paren_index = signature_body.find("(")
    if open_paren_index < 0:
        return []

    # Find matching ')' while respecting quoted strings.
    paren_depth = 0
    in_single_quotes = False
    in_double_quotes = False
    args_start_index = open_paren_index + 1
    args_end_index = None
    for scan_index in range(open_paren_index, len(signature_body)):
        char = signature_body[scan_index]
        if char == "'" and not in_double_quotes:
            in_single_quotes = not in_single_quotes
        elif char == '"' and not in_single_quotes:
            in_double_quotes = not in_double_quotes
        elif not in_single_quotes and not in_double_quotes:
            if char == "(":
                paren_depth += 1
            elif char == ")":
                paren_depth -= 1
                if paren_depth == 0:
                    args_end_index = scan_index
                    break
    if args_end_index is None:
        return []

    argument_list_text = signature_body[args_start_index:args_end_index].strip()
    if not argument_list_text:
        return []

    raw_arguments = _split_args_list(argument_list_text)

    # Normalize items (remove default assignments, size specs are not in signature anyway)
    # Filter out ~
    input_names = []
    for raw_argument in raw_arguments:
        raw_argument = raw_argument.strip()
        if not raw_argument or raw_argument == "~":
            continue
        # signature args could be "varargin" etc; keep as-is
        input_names.append(raw_argument)
    return input_names


# %% Arguments block parsing
_ARGS_START_RE = re.compile(r"^\s*arguments\b(\s*\(.*\))?\s*$")
_END_LINE_RE = re.compile(r"^\s*end\b(\s*%.*)?\s*$")
_BLOCK_COMMENT_START_RE = re.compile(r"^\s*%{\s*$")
_BLOCK_COMMENT_END_RE = re.compile(r"^\s*%}\s*$")

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

def _line_is_arguments_start(line_text: str, in_block_comment: bool) -> bool:
    """Return True if a line starts an arguments block.

    Args:
        line_text: Line to inspect.
        in_block_comment: Whether the parser is inside a `%{ %}` comment.

    Returns:
        True if the line is a valid `arguments` start line.
    """
    if in_block_comment:
        return False
    if _is_line_commented(line_text):
        return False
    stripped_line = _strip_inline_comment_best_effort(line_text).strip()
    return bool(_ARGS_START_RE.match(stripped_line))

def _find_arguments_blocks(file_lines: list[str]) -> list[ArgumentsBlockInfo]:
    """Find uncommented MATLAB arguments blocks in a list of lines.

    Args:
        file_lines: File contents split into lines.

    Returns:
        List of arguments block metadata entries.
    """
    found_blocks: list[ArgumentsBlockInfo] = []
    inside_block_comment = False
    line_index = 0
    while line_index < len(file_lines):
        current_line = file_lines[line_index]

        # Track %{ %} block comments to avoid false positives inside block-commented regions.
        if _BLOCK_COMMENT_START_RE.match(current_line):
            inside_block_comment = True
            line_index += 1
            continue
        if inside_block_comment:
            if _BLOCK_COMMENT_END_RE.match(current_line):
                inside_block_comment = False
            line_index += 1
            continue

        # Detect arguments start (uncommented only).
        if _line_is_arguments_start(current_line, in_block_comment=inside_block_comment):
            # Scan forward to locate the matching end line.
            scan_index = line_index + 1
            while scan_index < len(file_lines):
                scan_line = file_lines[scan_index]
                # Skip block-comment sections nested in the arguments block.
                if _BLOCK_COMMENT_START_RE.match(scan_line):
                    skip_index = scan_index + 1
                    while skip_index < len(file_lines) and not _BLOCK_COMMENT_END_RE.match(file_lines[skip_index]):
                        skip_index += 1
                    scan_index = min(skip_index + 1, len(file_lines))
                    continue

                if not _is_line_commented(scan_line):
                    stripped_scan_line = _strip_inline_comment_best_effort(scan_line).strip()
                    if _END_LINE_RE.match(stripped_scan_line):
                        found_blocks.append(
                            ArgumentsBlockInfo(
                                start_line=line_index,
                                end_line=scan_index,
                                already_commented=False,
                            )
                        )
                        line_index = scan_index + 1
                        break
                scan_index += 1
            else:
                # No end found; ignore and continue scanning.
                line_index += 1
            continue

        line_index += 1

    return found_blocks


def _comment_with_marker(line_text: str) -> str:
    """Insert the compatibility marker after indentation.

    Args:
        line_text: Line to comment.

    Returns:
        Commented line with the marker, or the original line if already commented.
    """
    if _is_line_commented(line_text):
        return line_text
    # Preserve line endings so formatting and diff noise stay minimal.
    line_ending = ""
    if line_text.endswith("\r\n"):
        line_text = line_text[:-2]
        line_ending = "\r\n"
    elif line_text.endswith("\n"):
        line_text = line_text[:-1]
        line_ending = "\n"
    elif line_text.endswith("\r"):
        line_text = line_text[:-1]
        line_ending = "\r"
    match = re.match(r"^(\s*)(.*)$", line_text)
    assert match is not None
    indentation, content = match.group(1), match.group(2)
    return f"{indentation}{MARKER}{content}{line_ending}"


def _uncomment_marker(line_text: str) -> str:
    """Remove the compatibility marker if present after indentation.

    Args:
        line_text: Line to process.

    Returns:
        Line with marker removed when present, otherwise the original line.
    """
    # Preserve line endings so round-trips are byte-stable.
    line_ending = ""
    if line_text.endswith("\r\n"):
        line_text = line_text[:-2]
        line_ending = "\r\n"
    elif line_text.endswith("\n"):
        line_text = line_text[:-1]
        line_ending = "\n"
    elif line_text.endswith("\r"):
        line_text = line_text[:-1]
        line_ending = "\r"
    match = re.match(r"^(\s*)%<ARGCOMPAT2022A>\s?(.*)$", line_text)
    if not match:
        return f"{line_text}{line_ending}"
    indentation, content = match.group(1), match.group(2)
    return f"{indentation}{content}{line_ending}"


def _block_is_already_commented(file_lines: list[str], arguments_start_index: int) -> bool:
    """Check whether an arguments block is already commented.

    Args:
        file_lines: File contents split into lines.
        arguments_start_index: Line index of the `arguments` keyword.

    Returns:
        True if the arguments start line is commented.
    """
    return _is_line_commented(file_lines[arguments_start_index])


def _disable_blocks(file_lines: list[str], argument_blocks: list[ArgumentsBlockInfo]) -> tuple[list[str], int]:
    """Disable arguments blocks by inserting the compatibility marker.

    Args:
        file_lines: File contents split into lines.
        argument_blocks: Arguments block metadata.

    Returns:
        Tuple of the updated lines and the number of modified blocks.
    """
    updated_lines = file_lines[:]
    modified_block_count = 0
    for block_info in argument_blocks:
        if _block_is_already_commented(updated_lines, block_info.start_line):
            # Pattern detected but already commented: keep the original block unchanged.
            continue
        # Comment the block start/end lines and contents, skipping manual comments.
        for line_index in range(block_info.start_line, block_info.end_line + 1):
            # Only comment lines that are not already commented or already marked.
            if re.match(r"^\s*%<ARGCOMPAT2022A>", updated_lines[line_index]):
                continue
            if _is_line_commented(updated_lines[line_index]):
                continue
            updated_lines[line_index] = _comment_with_marker(updated_lines[line_index])
        modified_block_count += 1
    return updated_lines, modified_block_count


def _enable_blocks(file_lines: list[str]) -> tuple[list[str], int]:
    """Enable arguments blocks by removing the compatibility marker.

    Args:
        file_lines: File contents split into lines.

    Returns:
        Tuple of updated lines and the number of marker lines uncommented.
    """
    updated_lines = file_lines[:]
    uncommented_line_count = 0
    for line_index, line_text in enumerate(updated_lines):
        if re.match(r"^\s*%<ARGCOMPAT2022A>", line_text):
            updated_lines[line_index] = _uncomment_marker(line_text)
            uncommented_line_count += 1
    return updated_lines, uncommented_line_count


# %% Arguments count cross-check
def _collect_arguments_entries(file_lines: list[str], block_info: ArgumentsBlockInfo) -> tuple[int, int, int]:
    """Count positional and keyword entries within an arguments block.

    Heuristics:
        - Join continuation lines ending with `...`.
        - Ignore blank lines and pure comments.
        - For each statement, use the first token:
          - If token contains `.`, the root before `.` is a keyword group.
          - If the statement contains `=`, treat as a keyword singleton.
          - Otherwise, treat as positional.

    Args:
        file_lines: File contents split into lines.
        block_info: Arguments block metadata.

    Returns:
        Tuple of positional count, keyword group count, and total effective count.
    """
    # Build statement strings so line continuations are counted as one entry.
    statements: list[str] = []
    current_statement = ""

    for line_index in range(block_info.start_line + 1, block_info.end_line):  # between arguments and end
        raw_line = file_lines[line_index]

        # If block is disabled with marker, lines may be prefixed; strip marker before analysis.
        uncommented_line = _uncomment_marker(raw_line)

        if _is_line_commented(uncommented_line):
            continue
        stripped_line = _strip_inline_comment_best_effort(uncommented_line).strip()
        if not stripped_line:
            continue

        if stripped_line.endswith("..."):
            current_statement += " " + stripped_line[:-3].rstrip()
            continue
        else:
            current_statement += " " + stripped_line
            statements.append(current_statement.strip())
            current_statement = ""

    if current_statement.strip():
        statements.append(current_statement.strip())

    positional_count = 0
    keyword_group_roots = set()

    for statement in statements:
        # First token: up to first whitespace or '(' or '='
        token_match = re.match(r"^([A-Za-z]\w*(?:\.[A-Za-z]\w*)?)", statement)
        if not token_match:
            continue
        token = token_match.group(1)

        if "." in token:
            keyword_root = token.split(".", 1)[0]
            keyword_group_roots.add(keyword_root)
        else:
            if "=" in statement:
                # likely name-value singleton
                keyword_group_roots.add(token)
            else:
                positional_count += 1

    keyword_group_count = len(keyword_group_roots)
    return positional_count, keyword_group_count, positional_count + keyword_group_count


# %% Main processing
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


def _process_file(file_path: Path, mode: str, do_check: bool, dry_run: bool, backup: bool) -> FileReport:
    """Process a single MATLAB file for arguments block updates.

    Args:
        file_path: Path to the file to process.
        mode: Either `disable` or `enable`.
        do_check: Whether to perform signature/arguments cross-checks.
        dry_run: Whether to skip writing changes to disk.
        backup: Whether to write a `.bak` copy on the first change.

    Returns:
        FileReport summarizing the actions taken.
    """

    # Read file contents
    file_text = file_path.read_text(encoding="utf-8", errors="replace")
    file_lines = file_text.splitlines(keepends=True)

    warnings: list[str] = []

    # Optional signature extraction (best-effort: first function in file).
    signature_inputs: list[str] = []

    # For each line, look for function signature.
    for line_index, line_text in enumerate(file_lines):
        if _FUNC_LINE_RE.match(line_text) and not _is_line_commented(line_text):
            signature_line, _ = _collect_function_signature(file_lines, line_index)
            signature_inputs = _parse_signature_inputs(signature_line)
            break

    # Find process arguments blocks if any
    argument_blocks = _find_arguments_blocks(file_lines)

    modified_block_count = 0
    uncommented_line_count = 0

    # Process according to mode
    if mode == "disable":
        updated_lines, modified_block_count = _disable_blocks(file_lines, argument_blocks)
    elif mode == "enable":
        updated_lines, uncommented_line_count = _enable_blocks(file_lines)
    else:
        raise ValueError(f"Unknown mode: {mode}")

    # Determine if file changed
    file_changed = (updated_lines != file_lines)

    # Cross-check arguments count against signature input count.
    if do_check and argument_blocks:
        # Sum across blocks; most files only have a single arguments block.
        positional_sum = 0
        keyword_group_sum = 0
        effective_sum = 0
        for block_info in argument_blocks:
            positional, keyword_groups, effective = _collect_arguments_entries(file_lines, block_info)
            positional_sum += positional
            keyword_group_sum += keyword_groups
            effective_sum += effective

        if signature_inputs:
            signature_input_count = len(signature_inputs)
            # Heuristic: if signature includes varargin, allow extra keyword groups.
            has_varargin = any(item.strip() == "varargin" for item in signature_inputs)
            if not has_varargin and signature_input_count != effective_sum:
                warnings.append(
                    "Signature inputs="
                    f"{signature_input_count} but arguments effective entries="
                    f"{effective_sum} (pos={positional_sum}, kwGroups={keyword_group_sum})."
                )
            if has_varargin and signature_input_count > effective_sum:
                warnings.append(
                    "Signature includes varargin; signature inputs="
                    f"{signature_input_count} > arguments effective entries="
                    f"{effective_sum} (pos={positional_sum}, kwGroups={keyword_group_sum})."
                )
        else:
            warnings.append("Could not parse function signature (skipped signature/arguments cross-check).")

    # Write back only if changes are needed and dry-run is off.
    if file_changed and not dry_run:
        if backup:
            backup_path = file_path.with_suffix(file_path.suffix + ".bak")
            if not backup_path.exists():
                backup_path.write_text(file_text, encoding="utf-8")
        file_path.write_text("".join(updated_lines), encoding="utf-8")

    return FileReport(
        path=file_path,
        changed=file_changed,
        blocks_found=len(argument_blocks),
        blocks_modified=modified_block_count,
        enable_lines_uncommented=uncommented_line_count,
        warnings=warnings,
    )


def _iter_m_files(root_path: Path) -> list[Path]:
    """Recursively enumerate MATLAB `.m` files under a root directory.

    Args:
        root_path: Root directory to scan.

    Returns:
        List of `.m` file paths found under the root.
    """
    matlab_files = []
    for file_path in root_path.rglob("*.m"):
        # Skip hidden folders and obvious vendor dirs.
        if any(part.startswith(".") for part in file_path.parts):
            continue
        matlab_files.append(file_path)
    return matlab_files


def main() -> int:
    """Run the command-line interface for arguments block updates.

    Returns:
        Exit code for the command.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True, help="Root folder to scan")
    parser.add_argument(
        "--mode",
        required=True,
        choices=["disable", "enable"],
        help="disable=comment arguments blocks, enable=restore",
    )
    parser.add_argument("--dry-run", action="store_true", help="Do not modify files, only report")
    parser.add_argument("--backup", action="store_true", help="Create .bak once per modified file")
    parser.add_argument("--check", action="store_true", help="Cross-check signature vs arguments counts (heuristic)")
    cli_args = parser.parse_args()

    root_path = Path(cli_args.root).resolve()
    if not root_path.exists():
        print(f"[ERR] Root does not exist: {root_path}", file=sys.stderr)
        return 2

    matlab_files = _iter_m_files(root_path)
    print(f"[INFO] Found {len(matlab_files)} .m files under {root_path}")

    changed_file_count = 0
    total_blocks_found = 0
    total_blocks_modified = 0
    total_marker_lines_uncommented = 0
    total_warnings_count = 0

    for file_path in matlab_files:
        report = _process_file(
            file_path=file_path,
            mode=cli_args.mode,
            do_check=cli_args.check,
            dry_run=cli_args.dry_run,
            backup=cli_args.backup,
        )
        total_blocks_found += report.blocks_found
        total_blocks_modified += report.blocks_modified
        total_marker_lines_uncommented += report.enable_lines_uncommented

        if report.changed:
            changed_file_count += 1
            if cli_args.mode == "disable":
                print(
                    f"[MOD] {report.path} | blocks_found={report.blocks_found} "
                    f"blocks_modified={report.blocks_modified}"
                )
            else:
                print(
                    f"[MOD] {report.path} | marker_lines_uncommented={report.enable_lines_uncommented}"
                )
        else:
            # Keep logs readable; still show files with warnings.
            if report.warnings:
                print(f"[CHK] {report.path} | no change")

        for warning in report.warnings:
            total_warnings_count += 1
            print(f"  [WARN] {warning}")

    print(
        f"[INFO] Mode={cli_args.mode} dry_run={cli_args.dry_run} "
        f"backup={cli_args.backup} check={cli_args.check}"
    )
    print(f"[INFO] Files changed: {changed_file_count}/{len(matlab_files)}")
    print(f"[INFO] Arguments blocks found: {total_blocks_found}")
    if cli_args.mode == "disable":
        print(f"[INFO] Arguments blocks modified: {total_blocks_modified}")
    else:
        print(f"[INFO] Marker lines uncommented: {total_marker_lines_uncommented}")
    print(f"[INFO] Warnings: {total_warnings_count}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
