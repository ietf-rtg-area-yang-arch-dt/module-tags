#Crazy makefile authored by Lou Berger <lberger@labn.net>
#Modified by Christian Hopps <chopps@chopps.org>
#The author makes no claim/restriction on use.  It is provided "AS IS".
#This file is considered a hack and not production grade by the author

DRAFT  = draft-rtgyangdt-netmod-module-tags
MODELS = ietf-module-tags.yang \
	 ietf-library-tags.yang \
	 sample-module.yang

#assumes standard yang modules installed in ../yang, customize as needed
#  e.g., based on a 'cd .. ; git clone https://github.com/YangModels/yang.git'
YANGIMPORT_BASE = ../yang
PLUGPATH    := $(shell echo `find $(YANGIMPORT_BASE) -name \*.yang | sed 's,/[a-z0-9A-Z@_\-]*.yang$$,,' | uniq` | tr \  :)
# PYTHONPATH  := $(shell echo `find /usr/lib* /usr/local/lib* -name  site-packages ` | tr \  :)
WITHXML2RFC := $(shell which xml2rfc > /dev/null 2>&1 ; echo $$? )

ID_DIR	     = IDs
REVS	    := $(shell \
		 sed -e '/docName="/!d;s/.*docName="\([^"]*\)".*/\1/' $(DRAFT).xml | \
		 awk -F- '{printf "%02d %02d",$$NF-1,$$NF}')
PREV_REV    := $(word 1, $(REVS))
REV	    := $(word 2, $(REVS))
OLD          = $(ID_DIR)/$(DRAFT)-$(PREV_REV)
NEW          = $(ID_DIR)/$(DRAFT)-$(REV)

TREES := $(MODELS:.yang=.tree)

%.tree: %.yang
	@echo Updating $< revision date
	@rm -f $<.prev; cp -pf $< $<.prev 
	@sed 's/revision.\"[0-9]*\-[0-9]*\-[0-9]*\"/revision "'`date +%F`'"/' < $<.prev > $<
	@diff $<.prev $< || exit 0
	@echo Generating $@	
	pyang --ietf -f tree -p $(PLUGPATH) $< > $@  || exit 0

	# @PYTHONPATH=$(PYTHONPATH) pyang --ietf -f tree -p $(PLUGPATH) $< > $@  || exit 0

%.txt: %.xml
	rm -f $@.prev
	if [ -f $@ ]; then cp -pf $@ $@.prev; fi
	xml2rfc $<
	if [ -f $@.prev ]; then diff $@.prev $@; fi || exit 0

%.html: %.xml
	@if [ $(WITHXML2RFC) == 0 ] ; then 	\
		rm -f $@.prev; cp -pf $@ $@.prev ; \
		xml2rfc --html $< 		; \
	fi

all:	$(TREES) $(DRAFT).txt $(DRAFT).html

clean:
	rm -f *.txt *.html *.prev *.tree

vars:
	@echo PYTHONPATH=$(PYTHONPATH)
	@echo PLUGPATH=$(PLUGPATH)
	@echo PREV_REV=$(PREV_REV)
	@echo REV=$(REV)
	@echo OLD=$(OLD)

$(DRAFT).xml: $(MODELS)
	@rm -f $@.prev; cp -p $@ $@.prev
	@for model in $? ; do \
		rm -f $@.tmp; cp -p $@ $@.tmp	 		 	; \
		echo Updating $@ based on $$model		 	; \
		base=`echo $$model | cut -d. -f 1` 		 	; \
		start_stop=(`awk 'BEGIN{pout=1}				\
			/^<CODE BEGINS> file .'$${base}'/ 		\
				{pout=0; print NR-1;} 			\
			pout == 0 && /^<CODE E/ 			\
				{pout=1; print NR;}			\
                        END{print "0 0"}' $@.tmp`) 		; \
		echo start_stop=$${start_stop[0]},$${start_stop[1]} ; \
		if [ $${start_stop[0]} -gt 0 ] ; then \
			head -$${start_stop[0]}    $@.tmp    		> $@	; \
			echo '<CODE BEGINS> file "'$${base}'@'`date +%F`'.yang"'>> $@;\
			cat $$model					>> $@	; \
			tail -n +$${start_stop[1]} $@.tmp 		>> $@	; \
			rm -f $@.tmp 		 				; \
		fi ; \
	done
	@if [ -f $@.prev ]; then diff -bw $@.prev $@; fi || exit 0


$(DRAFT)-diff.txt: $(DRAFT).txt 
	@echo "Generating diff of $(OLD).txt and $(DRAFT).txt > $@..."
	if [ -f  $(OLD).txt ] ; then \
		sdiff --ignore-space-change --expand-tabs -w 168 $(OLD).txt $(DRAFT).txt | \
		cut -c84-170 | sed 's/. *//'  \
		| grep -v '^ <$$' | grep -v '^<$$' > $@ ;\
	fi

idnits: $(DRAFT).txt
	@if [ ! -f idnits ] ; then \
		-rm -f $@ 					;\
		wget http://tools.ietf.org/tools/idnits/idnits	;\
		chmod 755 idnits				;\
	fi
	idnits $(DRAFT).txt

id: $(DRAFT).txt $(DRAFT).html
	@if [ ! -e $(ID_DIR) ] ; then \
		echo "Creating $(ID_DIR) directory" 	;\
		mkdir $(ID_DIR) 			;\
		git add $(ID_DIR)			;\
	fi
	@if [ -f "$(NEW).xml" ] ; then \
		echo "" 				;\
		echo "$(NEW).xml already exists, not overwriting!" ;\
		diff -sq $(DRAFT).xml  $(NEW).xml 	;\
		echo "" 				;\
	else \
		echo "Copying to $(NEW).{xml,txt,html}" ;\
		echo "" 				;\
		cp -p $(DRAFT).xml $(NEW).xml  		;\
		cp -p $(DRAFT).txt $(NEW).txt  		;\
		cp -p $(DRAFT).html $(NEW).html  	;\
		git add $(NEW).xml $(NEW).txt  $(NEW).html ;\
		ls -lt $(DRAFT).* $(NEW).* 		;\
	fi

rmid:
	@echo "Removing:"
	@ls -l $(NEW).xml $(NEW).txt  $(NEW).html
	@echo -n "Hit <ctrl>-C to abort, or <CR> to continue: "
	@read t
	@rm -f $(NEW).xml $(NEW).txt $(NEW).html
	@git rm  $(NEW).xml $(NEW).txt $(NEW).html

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
