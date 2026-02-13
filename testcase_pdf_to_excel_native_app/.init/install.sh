#!/usr/bin/env bash
set -euo pipefail
# idempotent dependency installer for workspace venv
WORKSPACE="/home/kavia/workspace/code-generation/testlink-pdf-report-analyzer-7145-7154/testcase_pdf_to_excel_native_app"
VENV="$WORKSPACE/.venv"
PY="$VENV/bin/python3"
# create workspace dir if missing
mkdir -p "$WORKSPACE"
# ensure venv exists
if [ ! -d "$VENV" ]; then
  python3 -m venv "$VENV" || { echo 'venv creation failed' >&2; exit 3; }
fi
# ensure pip is available in venv
if [ ! -x "$PY" ]; then echo "venv python not found at $PY" >&2; exit 4; fi
# install requirements with retry loop (2 attempts)
RETRIES=2
i=0
until [ $i -ge $RETRIES ]; do
  "$PY" -m pip install --upgrade pip setuptools wheel >/dev/null 2>&1 && \
  "$PY" -m pip install -r "$WORKSPACE/requirements.txt" && break
  i=$((i+1))
  sleep 2
done
if [ $i -ge $RETRIES ]; then echo 'pip install failed' >&2; exit 5; fi
# Verify imports and print versions
"$PY" - <<'PYCODE'
import sys, importlib
pkgs = ['PyPDF2','pdfminer','openpyxl','bs4','reportlab','pytest']
for p in pkgs:
    try:
        # handle package name differences
        name = p
        if p == 'pdfminer':
            # prefer pdfminer.six import path if available
            try:
                m = importlib.import_module('pdfminer')
            except Exception:
                m = importlib.import_module('pdfminer.six')
        else:
            m = importlib.import_module(name if name != 'bs4' else 'bs4')
        ver = getattr(m, '__version__', None)
        print(p, 'ok', ver)
    except Exception as e:
        print('import-failed', p, e, file=sys.stderr)
        sys.exit(2)
print('deps-installed')
PYCODE
