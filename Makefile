ORG := module-tags.org
BASE := $(shell sed -e '/^\#+RFC_NAME:/!d;s/\#+RFC_NAME: *\(.*\)/\1/' $(ORG))
VERSION := $(shell sed -e '/^\#+RFC_VERSION:/!d;s/\#+RFC_VERSION: *\([0-9]*\)/\1/' $(ORG))
OUTPUT_BASE := ${BASE}-${VERSION}

all: $(BASE).xml $(OUTPUT_BASE).txt $(OUTPUT_BASE).html $(OUTPUT_BASE).pdf

clean:
	rm ${BASE}-*.{xml,txt,html,pdf}

# --------
# Building
# --------

$(BASE).xml: $(ORG) ox-rfc.el
	emacs -Q --batch --eval '(setq org-confirm-babel-evaluate nil)' -l ./ox-rfc.el $< -f ox-rfc-export-to-xml
	mv $(OUTPUT_BASE).xml $(BASE).xml

%-$(VERSION).txt: %.xml
	xml2rfc --text -o $@ $<

%-$(VERSION).html: %.xml
	xml2rfc --html -o $@ $<

%-$(VERSION).pdf: %.xml
	xml2rfc --pdf -o $@ $<

# ------------
# Verification
# ------------

idnits: $(OUTPUT_BASE).txt
	if [ ! -e idnits ]; then curl -fLO 'http://tools.ietf.org/tools/idnits/idnits'; chmod 755 idnits; fi
	./idnits $(OUTPUT_BASE).txt

# -----
# Tools
# -----

ox-rfc.el:
	curl -fLO 'https://raw.githubusercontent.com/choppsv1/org-rfc-export/master/ox-rfc.el'
