OUT_DIR := _site
TMP_DIR := _cache

.PHONY: default
default: build

########################################
# Command-line arguments
########################################

# make test-html-proofer:
#   - EXTERNAL_LINKS:
#     If set, external links are checked.


########################################
# Initialize Git Hooks
########################################

.PHONY: init
init:
	git config core.hooksPath .githooks


########################################
# Build site with Shake
########################################

CABAL ?= cabal

SHAKE_ARGS += -j
SHAKE_ARGS += --lint
SHAKE_ARGS += --profile=$(TMP_DIR)/reports/build.html
SHAKE_ARGS += --timing

HTML_MINIFIER ?= npm_config_yes=true npx html-minifier

HTML_MINIFIER_ARGS += --collapse-whitespace
HTML_MINIFIER_ARGS += --collapse-boolean-attributes
HTML_MINIFIER_ARGS += --minify-css
HTML_MINIFIER_ARGS += --minify-js
HTML_MINIFIER_ARGS += --minify-urls
HTML_MINIFIER_ARGS += --remove-comments
HTML_MINIFIER_ARGS += --input-dir=$(OUT_DIR)
HTML_MINIFIER_ARGS += --output-dir=$(OUT_DIR)
HTML_MINIFIER_ARGS += --file-ext=html

UNZIP ?= unzip

UNZIP_ARGS += -q
UNZIP_ARGS += -n
UNZIP_ARGS += -d $(OUT_DIR)

.PHONY: build
build:
	@echo "Building PLFA..."
	@mkdir -p $(TMP_DIR)/reports/
	@$(CABAL) $(CABAL_ARGS) v2-run builder -- build $(SHAKE_ARGS)
	@echo "Minifying HTML with html-minifier..."
	@$(HTML_MINIFIER) $(HTML_MINIFIER_ARGS)
	@echo "Unpacking legacy versions..."
	@$(UNZIP) $(UNZIP_ARGS) data/legacy/19.08.zip
	@$(UNZIP) $(UNZIP_ARGS)  data/legacy/20.07.zip

.PHONY: clean
clean:
	@$(CABAL) $(CABAL_ARGS) v2-run builder -- clean

.PHONY: clobber
clobber:
	@$(CABAL) $(CABAL_ARGS) v2-run builder -- clobber


########################################
# Watch for changes with fswatch
########################################

FSWATCH ?= fswatch

FSWATCH_ARGS += --event=IsFile
FSWATCH_ARGS += --event=Created
FSWATCH_ARGS += --event=Updated
FSWATCH_ARGS += --event=Removed
FSWATCH_ARGS += --event=Renamed
FSWATCH_ARGS += --event=MovedFrom
FSWATCH_ARGS += --event=MovedTo
FSWATCH_ARGS += --one-per-batch
FSWATCH_ARGS += --recursive
FSWATCH_ARGS += --exclude="\.git/.*"
FSWATCH_ARGS += --exclude="dist-newstyle/.*"
FSWATCH_ARGS += --exclude="$(OUT_DIR)/.*"
FSWATCH_ARGS += --exclude="$(TMP_DIR)/.*"
FSWATCH_ARGS += "."

.PHONY: watch
watch:
	$(FSWATCH) $(FSWATCH_ARGS) | xargs -n1 -I{} make build


########################################
# Start local server with BrowserSync
########################################

BROWSER_SYNC ?= npm_config_yes=true npx browser-sync

BROWSER_SYNC_ARGS += start
BROWSER_SYNC_ARGS += --server
BROWSER_SYNC_ARGS += --files "."
BROWSER_SYNC_ARGS += --no-ui
BROWSER_SYNC_ARGS += --reload-delay 500
BROWSER_SYNC_ARGS += --reload-debounce 500

.PHONY: serve
serve:
	@(cd $(OUT_DIR) && $(BROWSER_SYNC) $(BROWSER_SYNC_ARGS))


########################################
# Test site with:
# - html-validate
# - html-proofer
# - EPUBCheck
# - Ace by Daisy
########################################


# html-validate

HTML_VALIDATE ?= npm_config_yes=true npx html-minifier

HTML_VALIDATE_ARGS += .

.PHONY: test-html-validate
test-html-validate:
	@echo "Checking HTML with html-validate..."
	@(cd $(OUT_DIR) && $(HTML_VALIDATE) $(HTML_VALIDATE_ARGS))


# html-proofer

HTML_PROOFER ?= bundle exec htmlproofer

# In anticipation of html-proofer-4.0.0
# HTML_PROOFER_ARGS += --cache="{cache: {timeframe: {external: '30d'}, storage_dir: '$(TMP_DIR)/html-proofer'}}"
# HTML_PROOFER_ARGS += --ignore-files="/\.\/plfa.html/,/\.\/assets\/.*\.html/"
# HTML_PROOFER_ARGS += --ignore-urls="/github.com/"

HTML_PROOFER_ARGS += --check-html
HTML_PROOFER_ARGS += --check-img-http
HTML_PROOFER_ARGS += --check-opengraph
HTML_PROOFER_ARGS += --file-ignore="/\.\/plfa.html/,/\.\/assets\/.*\.html/"
ifeq ($(EXTERNAL_LINKS),)
HTML_PROOFER_ARGS += --disable-external
else
HTML_PROOFER_ARGS += --url-ignore="/github.com/"
endif
HTML_PROOFER_ARGS += --report-eof-tags
HTML_PROOFER_ARGS += --report-invalid-tags
HTML_PROOFER_ARGS += --report-missing-names
HTML_PROOFER_ARGS += --report-missing-doctype
HTML_PROOFER_ARGS += --report-mismatched-tags
HTML_PROOFER_ARGS += --report-script-embeds
HTML_PROOFER_ARGS += .

.PHONY: test-html-proofer
test-html-proofer:
	@echo "Checking HTML with HTMLProofer..."
	@(cd $(OUT_DIR) && $(HTML_PROOFER) $(HTML_PROOFER_ARGS))


# EPUBCheck

EPUBCHECK ?= epubcheck

EPUBCHECK_ARGS += --customMessages .epubcheck.tsv
EPUBCHECK_ARGS += $(OUT_DIR)/plfa.epub

.PHONY: test-epubcheck
test-epubcheck:
	@echo "Checking EPUB with EPUBCheck..."
	@$(EPUBCHECK) $(EPUBCHECK_ARGS)


# Ace by Daisy

ACE ?= npm_config_yes=true npx @daisy/ace

ACE_ARGS += --lang=en
ACE_ARGS += --tempdir=$(TMP_DIR)/ace
ACE_ARGS += --outdir=$(TMP_DIR)/ace
ACE_ARGS += $(OUT_DIR)/plfa.epub

.PHONY: test-ace
test-ace:
	@echo "Checking EPUB with Ace by DAISY..."
	@$(ACE) $(ACE_ARGS)
	@echo "See report: $(TMP_DIR)/ace/report.html"
