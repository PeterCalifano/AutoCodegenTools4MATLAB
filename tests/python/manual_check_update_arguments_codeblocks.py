from __future__ import annotations

import importlib.util
import os, sys
import tempfile
import types
from pathlib import Path


def _load_module() -> types.ModuleType:
    # Load the tool module by path so the script is self-contained.
    this_script_path = os.path.dirname(Path(__file__).resolve())
    
    # Construct relative path to the target module
    target_module_path = Path(this_script_path) / ".." / ".." / "python" / "update_arguments_codeblocks.py"

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

# Helper function to print banners for clarity in output.
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
        module_under_test._process_file(path, mode="disable", do_check=True, dry_run=False, backup=False)
        _print_banner("DISABLED")
        print(path.read_text(encoding="utf-8"))

        # Step 5: re-enable arguments blocks and show the restored file.
        module_under_test._process_file(path, mode="enable", do_check=True, dry_run=False, backup=False)
        _print_banner("REENABLED")
        print(path.read_text(encoding="utf-8"))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
