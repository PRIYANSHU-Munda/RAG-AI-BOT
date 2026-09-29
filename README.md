# FinRAG — local-first RAG for public-company filings

Layout-aware ingestion → table-preserving, structure-aware chunking → hybrid retrieval (dense + BM25 + RRF) → rerank → numeric/table-aware boost →
evidence-sufficiency check → grounded generation → **citation / numeric / NLI guards → answer or refusal**, with document-level ACLs enforced *before* retrieval.

## Quick start (offline, no ML dependencies)
```bash
cp .env.example .env
pip install -r requirements.txt
make ingest      # builds index from seed_data/, creates demo users (alice, bob, carol, root; password = <user>-pass)
make test        # 40+ unit / integration / security tests
make evaluate    # ablations A–I + table fidelity -> results/
make gate        # CI quality gate
uvicorn app.main:app   # UI at http://localhost:8000
# or: docker compose up   (add --profile llm for Ollama)
```

## What is implemented (and verified in this repo)
| Area | Status |
|---|---|
| Table parsing: bracketed negatives, units/currency, header-bound row chunks, footnotes, cross-page reconstruction, corruption warnings | ✅ tested |
| Chunking: section/paragraph children, table + table-row chunks, parent-child, summary-backed multi-vector (summary → raw resolution) | ✅ tested |
| Retrieval: dense, BM25, hybrid RRF, rerank, numeric/table boost, evidence sufficiency (period, annual-vs-quarterly, metric coverage) | ✅ tested |
| Guards: citation validation, numeric consistency (units, signs, %, years, calculations), NLI hook, prompt-injection screening | ✅ tested |
| Security: PBKDF2 auth, signed tokens, viewer/editor/admin, ACL filter before scoring, deletion enforcement, audit log | ✅ tested (FastAPI tests in `tests/test_api.py` need `pip install -r requirements.txt`) |
| Evaluation: golden set, ablations A–I, table fidelity, threshold gate, CI workflow | ✅ runs |
| Docling / sentence-transformers / HF NLI / Ollama backends | ⚙️ wired via `.env`, **not exercised in the build sandbox** (no network) |

## Measured results — seed corpus only
Seed corpus, 17 golden questions (synthetic; NOT a benchmark of real filings).

| Configuration | Recall@5 | MRR | Numeric acc. | Citation acc. | Refusal acc. | Halluc. | Unauth. | Table fid. | p95 ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A vector+fixed | 100% | 1.00 | 92% | 100% | 100% | 0% | 0 | 100% | 2.3 |
| B bm25+fixed | 100% | 0.96 | 85% | 92% | 100% | 0% | 0 | 100% | 1.5 |
| C hybrid+fixed | 100% | 1.00 | 92% | 100% | 100% | 0% | 0 | 100% | 1.5 |
| D hybrid+structure | 100% | 0.88 | 85% | 85% | 94% | 0% | 0 | 100% | 3.7 |
| E +reranker | 100% | 0.89 | 85% | 85% | 100% | 0% | 0 | 100% | 3.8 |
| F +numeric boost | 100% | 1.00 | 100% | 100% | 100% | 0% | 0 | 100% | 4.0 |
| G +parent-child | 100% | 1.00 | 100% | 100% | 100% | 0% | 0 | 100% | 5.1 |
| H +summary multi-vector | 100% | 1.00 | 100% | 100% | 100% | 0% | 0 | 100% | 5.3 |
| I full guarded | 100% | 1.00 | 100% | 100% | 100% | 0% | 0 | 100% | 6.1 |

**Read this honestly:** the seed corpus is 4 synthetic documents / ~54 chunks with 17 questions, so the ablation rows barely separate and
100% figures do *not* demonstrate real-filing performance. Defaults use a hashing embedder, a lexical reranker/NLI and an extractive generator so everything runs offline;
these are stand-ins. The spec's targets (10k+ chunks, 95% fidelity on real PDFs, p95 latency, FinanceBench) require you to run on real data:

1. `python scripts/fetch_edgar.py "Name email" AAPL MSFT NVDA` → convert to PDF / add `.meta.json` sidecars → put in `seed_data/` (or set `SEED_DIR`).
2. `pip install -r requirements-ml.txt`, set `EMBED_BACKEND=st RERANK_BACKEND=st NLI_BACKEND=hf LLM_BACKEND=ollama PARSER_BACKEND=docling`.
3. Hand-label table ground truth for real filings in `evaluation/tables_gt.json`; grow `golden.jsonl` to 100–200 questions.
4. `python scripts/prepare_financebench.py` then `python evaluation/run_eval.py --golden evaluation/financebench.jsonl`.
5. Record hardware, models, versions, seeds here; update `evaluation/thresholds.json`; document real failures in `FAILURE_ANALYSIS.md`.

## Design notes
- **Permissions before scoring:** unauthorized docs are removed from the candidate set before dense/BM25 scoring, so they can't influence ranks or reach the LLM.
- **Summaries are retrieval aids only:** a matched summary is swapped for its linked raw table/section before generation.
- **Boosts don't override quality:** numeric/table weights are small (0.1 each) and only reorder near-ties; sufficiency checks still gate answers.
- **NLI is a secondary signal:** numeric/source checks are separate and blocking; NLI blocks only claims containing figures.
- **Streaming:** `/chat/stream` streams only after validation.
- **Not implemented:** encryption at rest/in transit (deploy behind TLS, encrypted volumes), secret manager, multi-tenant isolation beyond ACL groups, LLM-based query rewriting, HotpotQA runner, local-vs-hosted comparison harness.
- Seed filings are **synthetic**. Never treat them as real financial data.
