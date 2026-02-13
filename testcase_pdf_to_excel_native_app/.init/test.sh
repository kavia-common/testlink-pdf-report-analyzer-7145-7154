#!/usr/bin/env bash
set -euo pipefail
# Run pytest tests that create their own PDF via reportlab and invoke the CLI via the venv python
WORKSPACE="/home/kavia/workspace/code-generation/testlink-pdf-report-analyzer-7145-7154/testcase_pdf_to_excel_native_app"
VENV="$WORKSPACE/.venv"
PY="$VENV/bin/python3"
# Ensure tests dir exists
mkdir -p "$WORKSPACE/tests"
# Create pytest file with workspace variables expanded now to avoid heredoc expansion problems at runtime
cat > "$WORKSPACE/tests/test_cli.py" <<PYTEST
import subprocess
from pathlib import Path
from reportlab.pdfgen import canvas

def make_pdf(p: Path):
    p.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(p))
    c.drawString(100,750,'hello')
    c.save()

def test_cli_writes_xlsx(tmp_path):
    pdf = tmp_path / 'sample.pdf'
    make_pdf(pdf)
    out = tmp_path / 'out.xlsx'
    venv_py = Path("$WORKSPACE") / '.venv' / 'bin' / 'python3'
    cli = Path("$WORKSPACE") / 'src' / 'cli.py'
    res = subprocess.run([str(venv_py), str(cli), str(pdf), str(out)], capture_output=True, text=True, timeout=30)
    assert res.returncode == 0, res.stderr
    assert out.exists()

def test_openpyxl_can_write(tmp_path):
    from openpyxl import Workbook
    p = tmp_path / 't.xlsx'
    wb = Workbook()
    wb.active['A1'] = 'ok'
    wb.save(p)
    assert p.exists()
PYTEST

# Execute pytest using the venv python
if [ ! -x "$PY" ]; then
  echo "ERROR: venv python not found at $PY" >&2
  exit 2
fi
# Run pytest; exit code will propagate
"$PY" -m pytest -q "$WORKSPACE/tests"
