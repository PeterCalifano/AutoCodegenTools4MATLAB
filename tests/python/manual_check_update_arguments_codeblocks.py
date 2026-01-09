from __future__ import annotations

import importlib.util
import tempfile
import types
from pathlib import Path
from typing import Optional


def _load_module() -> types.ModuleType:
    # Load the tool module by path so the script is self-contained.
    module_path: Optional[Path] = None
    for parent in Path(__file__).resolve().parents:
        candidate = parent / "script" / "code_generation" / "python_tools" / "update_arguments_codeblocks.py"
        if candidate.exists():
            module_path = candidate
            break
    if module_path is None:
        raise FileNotFoundError("Could not locate update_arguments_codeblocks.py")

    spec = importlib.util.spec_from_file_location("update_arguments_codeblocks", module_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


UACB = _load_module()


def _print_banner(title: str) -> None:
    print("=" * 10 + f" {title} " + "=" * 10)


def main() -> int:
    # Step 1: define representative MATLAB content for manual inspection.
    content = (
        "function out = demo(a, b)\n"
        "arguments\n"
        "  a (1,1) double\n"
        "  % already commented line\n"
        "  b (1,1) double = 3 % inline comment\n"
        "  opts.alpha (1,1) double = 1\n"
        "end\n"
        "out = a + b;\n"
        "end\n"
    )

    with tempfile.TemporaryDirectory() as tmpdir:
        # Step 2: write the content to a temporary file.
        path = Path(tmpdir) / "demo.m"
        path.write_text(content, encoding="utf-8")

        # Step 3: show the original file contents.
        _print_banner("ORIGINAL")
        print(path.read_text(encoding="utf-8"))

        # Step 4: disable arguments blocks and show the updated file.
        UACB._process_file(path, mode="disable", do_check=True, dry_run=False, backup=False)
        _print_banner("DISABLED")
        print(path.read_text(encoding="utf-8"))

        # Step 5: re-enable arguments blocks and show the restored file.
        UACB._process_file(path, mode="enable", do_check=True, dry_run=False, backup=False)
        _print_banner("REENABLED")
        print(path.read_text(encoding="utf-8"))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
