# Failure analysis

Format per entry: **Failure → Root cause → Detection → Fix → Before/After → Remaining limitation.**
Entries 1–4 are real failures hit while building this repo (measured on the synthetic seed corpus, 17 golden questions).
Entries in the "Not yet observed" list still need real evidence from a real-filing run — do not claim them until measured.

## 1. Corrupted table cells slipped past validation
- **Root cause:** `validate_table` only inspected columns ≥60% numeric; a column with 2 of 4 corrupted cells (`1O0`, `(5`) was skipped.
- **Detection:** unit test `test_corrupted_table_is_flagged_not_silent` failed.
- **Fix:** threshold lowered to 50%; explicit `possible_ocr_digit_error` (O/o/I/l inside numbers) and unbalanced-parenthesis checks.
- **Before → after:** corrupted cells flagged 0/3 → 3/3 in the unit fixture.
- **Limitation:** heuristic. Wrong-but-well-formed digits (e.g. `150` read as `160`) are invisible; needs page-image/GT verification (table-fidelity metric).

## 2. Narrative question answered with a table row
- **Root cause:** extractive generator checked `table_row` evidence first in a loop, ignoring its own "narrative" reordering.
- **Detection:** golden question g06 ("What drove … Services revenue growth?"); numeric/keyword accuracy 92%.
- **Fix:** single ordered pass over evidence.
- **Before → after:** answer accuracy 92% → 100% (configs F–H).
- **Limitation:** intent detection is a keyword regex; an LLM query classifier would generalize better.

## 3. Guard false positive: years treated as figures
- **Root cause:** number regex captured the trailing comma in `2024,` so the year was treated as a numeric claim needing a citation.
- **Detection:** full guarded config refused g06 (config I: 92% vs 100% for H).
- **Fix:** regex requires digits at the end of the token; citation tag placed before the sentence period.
- **Before → after:** config I answer accuracy 92% → 100%, refusal accuracy 94% → 100%.
- **Limitation:** guards err toward refusal; every false refusal is a usability cost — track "over-refusal rate" on a larger set.

## 4. Guard false positive: numbers in the source footer
- **Root cause:** "Item 7", "10-K", "June 30" in the deterministic `Source:` footer were flagged as unsupported figures.
- **Fix:** footer (built from metadata, not model output) excluded from numeric/citation validation.
- **Limitation:** an LLM that fabricates a `Source:` section would bypass numeric checks for that text; when `LLM_BACKEND=ollama`, the prompt forbids it, but consider validating footers against chunk metadata.

## Not yet observed (need real-filing runs)
Scrambled PDF columns · OCR digit errors on scanned filings · rows detached from headers in Docling output · footnotes attached to wrong table ·
wrong fiscal year across many similar filings · summary embedding retrieving wrong raw evidence · arithmetic errors from the LLM ·
NLI false positives/negatives (the offline lexical NLI is only a coarse stand-in; validate the HF NLI model) · cross-company confusion at 10k+ chunks.
