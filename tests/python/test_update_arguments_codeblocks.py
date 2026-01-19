from __future__ import annotations

import importlib.util
import os
import sys
import tempfile
import types
from pathlib import Path


def _load_module() -> types.ModuleType:
    # Load the tool module by path so the script is self-contained.
    this_script_path = os.path.dirname(Path(__file__).resolve())

    # Construct relative path to the target module
    target_module_path = Path(this_script_path) / ".." / \
        ".." / "python" / "update_arguments_codeblocks.py"

    # Assert the target module exists
    if not target_module_path.exists():
        raise FileNotFoundError(f"Could not locate {target_module_path}")

    spec = importlib.util.spec_from_file_location(
        "update_arguments_codeblocks", target_module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None

    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


module_under_test = _load_module()


def _write_tmp(tmp_path: Path, name: str, content: str) -> Path:
    # Create a temporary MATLAB file with the provided contents.
    path = tmp_path / name
    path.write_text(content, encoding="utf-8")
    return path


def test_disable_enable_roundtrip(tmp_path: Path) -> None:
    # Arrange: arguments block with mixed comments and name-value usage.
    content = (
        "function y = foo(x, y)\n"
        "arguments\n"
        "  x (1,1) double\n"
        "  % already comment\n"
        "  y double = 3 % comment\n"
        "  opts.alpha (1,1) double = 1\n"
        "end\n"
        "y = x + y;\n"
        "end\n"
    )
    path = _write_tmp(tmp_path, "foo.m", content)

    # Act: disable then re-enable the arguments block.
    rep = module_under_test._process_file(path, mode="disable", do_check=False, dry_run=False, backup=False)
    assert rep.blocks_found == 1
    assert rep.blocks_modified == 1

    disabled = path.read_text(encoding="utf-8")
    assert module_under_test.MARKER in disabled

    comment_line = next(ln for ln in disabled.splitlines() if "already comment" in ln)
    assert module_under_test.MARKER not in comment_line

    module_under_test._process_file(path, mode="enable", do_check=False, dry_run=False, backup=False)
    restored = path.read_text(encoding="utf-8")

    # Assert: round-trip restores original contents.
    assert restored == content


def test_disable_ignores_commented_arguments_block(tmp_path: Path) -> None:
    # Arrange: fully commented arguments block should be ignored.
    content = (
        "function y = foo(x)\n"
        "% arguments\n"
        "%   x (1,1) double\n"
        "% end\n"
        "y = x;\n"
        "end\n"
    )
    path = _write_tmp(tmp_path, "foo.m", content)

    # Act: disable should not modify anything.
    rep = module_under_test._process_file(path, mode="disable", do_check=False, dry_run=False, backup=False)
    assert rep.blocks_found == 0
    assert rep.changed is False


def test_find_arguments_blocks_ignores_block_comments_and_strings() -> None:
    # Arrange: one arguments block in a %{ %} comment and one real block.
    lines: list[str] = [
        "%{\n",
        "arguments\n",
        "  x (1,1) double\n",
        "end\n",
        "%}\n",
        "function y = foo(x)\n",
        "disp('arguments');\n",
        "arguments\n",
        "  x (1,1) double\n",
        "end\n",
    ]
    # Act: detect only the real arguments block.
    blocks = module_under_test._find_arguments_blocks(lines)

    # Assert: the block starts at the actual arguments line.
    assert len(blocks) == 1
    assert lines[blocks[0].start_line].strip() == "arguments"


def test_check_warns_on_signature_mismatch(tmp_path: Path) -> None:
    # Arrange: signature has fewer inputs than arguments entries.
    content = (
        "function y = foo(x, y)\n"
        "arguments\n"
        "  x (1,1) double\n"
        "  y (1,1) double\n"
        "  z (1,1) double\n"
        "end\n"
        "y = x + y;\n"
        "end\n"
    )
    path = _write_tmp(tmp_path, "foo.m", content)

    # Act: run in dry-run mode with checking enabled.
    rep = module_under_test._process_file(path, mode="disable", do_check=True, dry_run=True, backup=False)

    # Assert: mismatch produces a warning.
    assert rep.warnings
    assert "Signature inputs=" in rep.warnings[0]
