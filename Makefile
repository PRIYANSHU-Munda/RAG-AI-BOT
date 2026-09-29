.PHONY: ingest evaluate test gate all serve
ingest:   ; python scripts/ingest.py
evaluate: ; python evaluation/run_eval.py && python evaluation/table_fidelity.py
test:     ; python -m pytest -q
gate:     ; python evaluation/check_thresholds.py
serve:    ; uvicorn app.main:app --reload
all: ingest test evaluate gate
