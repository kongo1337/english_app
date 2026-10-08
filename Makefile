PYTHON := python3 -I

.PHONY: data check-translations extract ipa review

# Rebuild App/Resources/words.json from committed intermediate files (no network).
data: check-translations
	$(PYTHON) tools/build_words.py

check-translations:
	$(PYTHON) tools/check_batch.py

# Re-extract the lemma list from the Oxford PDFs in data/raw/ (needs poppler's pdftotext).
extract:
	$(PYTHON) tools/extract_oxford.py

# Re-extract transcriptions; download data/raw/ipa-dict/en_US.txt first (see tools/extract_ipa.py).
ipa:
	$(PYTHON) tools/extract_ipa.py

review: data
	$(PYTHON) tools/sample.py
