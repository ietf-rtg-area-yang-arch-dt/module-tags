ORG := module-tags.org
BASE := $(shell sed -e '/^\#+RFC_NAME:/!d;s/\#+RFC_NAME: *\(.*\)/\1/' $(ORG))
VERSION := $(shell sed -e '/^\#+RFC_VERSION:/!d;s/\#+RFC_VERSION: *\([0-9]*\)/\1/' $(ORG))
OUTPUT_BASE := ${BASE}-${VERSION}

all: $(OUTPUT_BASE).xml $(OUTPUT_BASE).txt $(OUTPUT_BASE).html $(OUTPUT_BASE).pdf

clean:
	rm ${BASE}-*.{xml,txt,html,pdf}

# --------
# Building
# --------

$(OUTPUT_BASE).xml: $(ORG) ox-rfc.el
	emacs -Q --batch --eval '(setq org-confirm-babel-evaluate nil)' -l ./ox-rfc.el $< -f ox-rfc-export-to-xml

%.txt: %.xml
	xml2rfc --text -o $@ $<

%.html: %.xml
	xml2rfc --html -o $@ $<

%.pdf: %.xml
	xml2rfc --pdf -o $@ $<

# ------------
# Verification
# ------------

nits: idnits $(OUTPUT_BASE).txt
	./idnits $(OUTPUT_BASE).txt

# -----
# Tools
# -----

ox-rfc.el:
	curl -fLO 'https://raw.githubusercontent.com/choppsv1/org-rfc-export/master/ox-rfc.el'

idnits:
	curl -fLO 'http://tools.ietf.org/tools/idnits/idnits'
	chmod 755 idnits

OBJDIR ?= build
PROJPATH := $(shell pwd)
YMB := ietf-module-tags
YMD := $(OBJDIR)/$(YMB)-data
YMC := $(OBJDIR)/$(YMB)-config
XMLC := $(wildcard tests/*.xml)
XMLD := test-data-tags.xml
TIDY := (which tidy > /dev/null 2> /dev/null && tidy -q -xml -indent || cat)
YMODULES := ietf-module-tags.yang ietf-library-tags.yang
XSLS  := $(YMODULES:%.yang=$(OBJDIR)/%.xsl)

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/%-config.rng $(OBJDIR)/%-config.sch $(OBJDIR)/%-config.dsrl: %.yang
	yang2dsdl -t config -d $(OBJDIR) $<

$(OBJDIR)/%-data.rng $(OBJDIR)/%-data.sch $(OBJDIR)/%-data.dsrl: %.yang
	yang2dsdl -t data -d $(OBJDIR)  $<

test-yang: $(YMODULES)
	pyang --ietf $<

test-config: $(OBJDIR) $(XMLC) $(YMC).rng $(YMC).sch $(YMC).dsrl

test-xml-config: test-config
	set -e; for t in $(XMLC); do \
		if [[ $${t##tests/test-bad} == $${t} ]]; then \
			echo "Running positive test $$(basename $$t)"; \
			yang2dsdl -t config -d $(OBJDIR) -b $(YMB) -s -v $$t >/dev/null 2>/dev/null; \
		else \
			echo "Running negative test $$(basename $$t)"; \
			not yang2dsdl -t config -d $(OBJDIR) -b $(YMB) -s -v $$t >/dev/null 2>/dev/null; \
		fi; \
	done;

test-data:  $(OBJDIR) $(XMLD) $(YMD).rng $(YMD).sch $(YMD).dsrl

test-xml-data: test-data
	yang2dsdl -t data -d $(OBJDIR) -b $(YMB) -s -v $(XMLD) # > /dev/null 2>/dev/null

# test-xml: test-xml-config test-xml-data test-yang
test: test-yang test-xml-config test-xml-data

extra: $(XSLS)


# export YANGBASE=$$(dirname $$(which yang2dsdl))/../share/yang;
# export PYANG_XSLT_DIR=$${YANGBASE}/xslt;
# export PYANG_RNG_LIBDIR=$${YANGBASE}/schema;
# echo $${PYANG_XSLT_DIR};
# echo $${PYANG_RNG_LIBDIR};
