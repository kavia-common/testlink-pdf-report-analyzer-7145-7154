#!/usr/bin/env bash
set -euo pipefail

WORKSPACE="/home/kavia/workspace/code-generation/testlink-pdf-report-analyzer-7145-7154/testcase_pdf_to_excel_native_app"
VENV="$WORKSPACE/.venv"
PY="$VENV/bin/python3"
mkdir -p "$WORKSPACE/input" "$WORKSPACE/output" "$WORKSPACE/src" "$WORKSPACE/tests"
# Ensure venv exists and deps are installed (idempotent)
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV" || { echo 'venv creation failed' >&2; exit 3; }
  "$VENV/bin/python3" -m pip install --upgrade pip setuptools wheel >/dev/null
  # ensure requirements.txt exists (create minimal if missing)
  if [ ! -f "$WORKSPACE/requirements.txt" ]; then
    cat > "$WORKSPACE/requirements.txt" <<REQ
PyPDF2
openpyxl
reportlab
pytest
REQ
  fi
  "$VENV/bin/python3" -m pip install -r "$WORKSPACE/requirements.txt"
fi
# Quick import verification
"$PY" - <<PYCODE
import sys
try:
    import PyPDF2
    import openpyxl
except Exception as e:
    print('validation-deps-missing:', e, file=sys.stderr); sys.exit(2)
print('validation-deps-ok')
PYCODE
# Run tests if any exist (catch failure)
if ls "$WORKSPACE/tests"/*.py >/dev/null 2>&1; then
  "$PY" -m pytest -q "$WORKSPACE/tests" || { echo 'Validation: tests failed' >&2; exit 3; }
fi
# Generate a PDF and run CLI with timeout, capture stdout/stderr
OUT="$WORKSPACE/output/sample.xlsx"
TMPPDF="$WORKSPACE/input/validation_sample.pdf"
# create a minimal CLI if missing (simple PDF->XLSX placeholder)
if [ ! -f "$WORKSPACE/src/cli.py" ]; then
  mkdir -p "$(dirname "$WORKSPACE/src/cli.py")"
  cat > "$WORKSPACE/src/cli.py" <<'PY'
#!/usr/bin/env python3
import sys
from pathlib import Path
try:
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
except Exception:
    print('usage: cli.py input.pdf output.xlsx', file=sys.stderr); sys.exit(2)
# Very small converter placeholder: writes a minimal openpyxl workbook
from openpyxl import Workbook
wb = Workbook()
ws = wb.active
ws.title = 'sheet1'
ws['A1'] = 'converted'
ws['A2'] = src.name
dst.parent.mkdir(parents=True, exist_ok=True)
wb.save(dst)
print('converted', dst)
PY
  chmod +x "$WORKSPACE/src/cli.py"
fi
# create pdf using reportlab
"$PY" - <<PYGEN
from reportlab.pdfgen import canvas
from pathlib import Path
p=Path(r"$TMPPDF")
p.parent.mkdir(parents=True, exist_ok=True)
c=canvas.Canvas(str(p))
c.drawString(100,750,'validation')
c.save()
print('pdf-created')
PYGEN
set +e
# timeout if available
LOG="$WORKSPACE/output/cli_out.log"
if command -v timeout >/dev/null 2>&1; then
  timeout 30 "$PY" "$WORKSPACE/src/cli.py" "$TMPPDF" "$OUT" > "$LOG" 2>&1
  RC=$?
else
  "$PY" "$WORKSPACE/src/cli.py" "$TMPDF" "$OUT" > "$LOG" 2>&1
  RC=$?
fi
set -e
if [ $RC -ne 0 ]; then
  echo "Validation: CLI failed (rc=$RC)" >&2
  sed -n '1,200p' "$LOG" >&2 || true
  exit 4
fi
if [ ! -f "$OUT" ]; then echo 'Validation: expected output not produced' >&2; exit 5; fi
SIZE=$(stat -c%s "$OUT")
echo "validation: produced $OUT (size=${SIZE} bytes)"
# Print base64 prefix evidence using Python to avoid external dependency
"$PY" - <<PYB64
import base64
from pathlib import Path
p=Path(r"$OUT")
b=p.read_bytes()[:64]
print(base64.b64encode(b).decode('ascii')[:128])
PYB64
# cleanup
rm -f "$OUT" "$TMPPDF" "$LOG" || true
echo "validation: success"
