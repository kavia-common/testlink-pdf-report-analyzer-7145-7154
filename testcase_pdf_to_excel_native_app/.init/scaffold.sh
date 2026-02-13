#!/usr/bin/env bash
set -euo pipefail
# scaffold: create project layout and helper files under authoritative WORKSPACE
WORKSPACE="/home/kavia/workspace/code-generation/testlink-pdf-report-analyzer-7145-7154/testcase_pdf_to_excel_native_app"
mkdir -p "$WORKSPACE/src" "$WORKSPACE/tests" "$WORKSPACE/input" "$WORKSPACE/output" || true
# CLI entrypoint (uses openpyxl stub to produce an xlsx)
cat > "$WORKSPACE/src/cli.py" <<'PY'
#!/usr/bin/env python3
"""Simple CLI scaffold for PDF->Excel conversion (skeleton)."""
import argparse
import sys
from pathlib import Path

def main():
    p = argparse.ArgumentParser(description='Convert PDF to Excel (skeleton)')
    p.add_argument('pdf', type=Path, help='input PDF file')
    p.add_argument('xlsx', type=Path, help='output XLSX path')
    args = p.parse_args()
    if not args.pdf.exists():
        print(f"Input PDF not found: {args.pdf}", file=sys.stderr)
        sys.exit(2)
    from openpyxl import Workbook
    wb = Workbook()
    ws = wb.active
    ws.title = 'Sheet1'
    ws['A1'] = 'stub'
    args.xlsx.parent.mkdir(parents=True, exist_ok=True)
    wb.save(args.xlsx)
    print(f"Wrote stub Excel to {args.xlsx}")

if __name__ == '__main__':
    main()
PY
chmod +x "$WORKSPACE/src/cli.py"
: > "$WORKSPACE/src/__init__.py"
# requirements (pinning recommended in CI via constraints.txt)
cat > "$WORKSPACE/requirements.txt" <<REQ
PyPDF2
pdfminer.six
openpyxl
beautifulsoup4
pytest
reportlab
REQ
# Makefile uses explicit venv python to avoid relying on sourced environments
cat > "$WORKSPACE/Makefile" <<MK
.PHONY: run test venv
WORKSPACE := $WORKSPACE
VENV := $(WORKSPACE)/.venv
PY := $(VENV)/bin/python3
run: venv
	@$(PY) $(WORKSPACE)/src/cli.py $(WORKSPACE)/input/sample.pdf $(WORKSPACE)/output/sample.xlsx
venv:
	@if [ ! -d "$(VENV)" ]; then python3 -m venv "$(VENV)"; fi
	@$(VENV)/bin/python3 -m pip install --upgrade pip >/dev/null

test: venv
	@$(VENV)/bin/python3 -m pytest -q
MK
# workspace-local activation helper
cat > "$WORKSPACE/activate.sh" <<ACT
# source this file to activate the workspace venv in interactive shells
VENV="$WORKSPACE/.venv"
if [ -f "$VENV/bin/activate" ]; then
    . "$VENV/bin/activate"
else
    echo "No venv found at $VENV; run 'make venv' or source after creation" >&2
fi
ACT
chmod +x "$WORKSPACE/activate.sh"
# README
cat > "$WORKSPACE/README.md" <<MD
# testcase_pdf_to_excel_native_app
Workspace: $WORKSPACE

Use: make run (Makefile uses the workspace venv explicitly). For interactive shells you may source $WORKSPACE/activate.sh to add the venv to your shell session.

Notes:
- The CLI is at src/cli.py and is executable.
- requirements.txt lists recommended packages (including reportlab for test PDF generation).
MD
# Minimal test placeholder to be expanded in later step
cat > "$WORKSPACE/tests/test_smoke.py" <<'PYT'
def test_smoke():
    # smoke placeholder; real tests will generate PDFs and call the CLI in later step
    assert True
PYT

echo "scaffold: created files under $WORKSPACE"
