# =====================================================================
#  Makefile aggregato - esercizi/parte1
#  Costruisce TUTTE le lezioni (ogni sottocartella che contiene esame.tex,
#  incluse quelle aggiunte in futuro) e raccoglie i PDF prodotti:
#    esercitazioni/<lezione>.pdf  -> domande SENZA soluzioni
#    soluzioni/<lezione>.pdf      -> domande CON soluzioni
#
#  Uso:
#    make            compila tutte le lezioni e popola le due cartelle
#    make <lezione>  compila solo quella lezione (nome della sottocartella)
#    make release    prepara release-assets/ con i PDF rinominati (per la CI)
#    make list       elenca le lezioni rilevate
#    make clean      pulisce ausiliari, cartelle di output e release-assets
# =====================================================================

SHELL := /bin/bash

# Sottocartelle-lezione: tutte quelle che contengono un esame.tex.
# Le cartelle di output (esercitazioni, soluzioni, release-assets) non lo
# contengono, quindi vengono escluse automaticamente.
LESSONS := $(patsubst %/,%,$(dir $(wildcard */esame.tex)))

ESERCIT := esercitazioni
SOLUZ   := soluzioni
RELDIR  := release-assets

.PHONY: all list clean distclean release $(LESSONS)

all: $(LESSONS)

# Ogni lezione: compila (usando il suo Makefile) e copia i due PDF rinominati.
$(LESSONS):
	@echo "==> Lezione: $@"
	@$(MAKE) --no-print-directory -C $@
	@mkdir -p $(ESERCIT) $(SOLUZ)
	@cp -f $@/esame.pdf     $(ESERCIT)/$@.pdf
	@cp -f $@/soluzioni.pdf $(SOLUZ)/$@.pdf
	@echo "    -> $(ESERCIT)/$@.pdf , $(SOLUZ)/$@.pdf"

# Prepara i file da allegare a una release GitHub, con nomi non ambigui:
#   <lezione>-esercitazione.pdf   (senza soluzioni)
#   <lezione>-soluzioni.pdf       (con soluzioni)
release: all
	@mkdir -p $(RELDIR)
	@for d in $(LESSONS); do \
	  cp -f $(ESERCIT)/$$d.pdf $(RELDIR)/$$d-esercitazione.pdf; \
	  cp -f $(SOLUZ)/$$d.pdf   $(RELDIR)/$$d-soluzioni.pdf; \
	done
	@echo "release-assets pronti in $(RELDIR)/"

list:
	@echo "Lezioni rilevate:"; for d in $(LESSONS); do echo "  - $$d"; done

clean:
	@for d in $(LESSONS); do $(MAKE) --no-print-directory -C $$d clean; done
	@rm -rf $(ESERCIT) $(SOLUZ) $(RELDIR)

distclean: clean
	@for d in $(LESSONS); do $(MAKE) --no-print-directory -C $$d distclean; done
