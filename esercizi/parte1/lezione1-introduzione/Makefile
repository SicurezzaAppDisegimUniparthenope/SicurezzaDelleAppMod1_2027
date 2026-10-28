# Makefile - compila i documenti dell'esercitazione (classe exam)
# Richiede una distribuzione LaTeX con latexmk, classe exam e pacchetto listings.
# 'make' produce esercitazione.pdf e soluzioni.pdf; 'make clean' rimuove gli ausiliari.

LATEXMK := latexmk
LATEXMKFLAGS := -pdf -interaction=nonstopmode -halt-on-error
DEPS := preambolo.tex elenco.tex $(wildcard domande/*.tex)
TARGETS := esercitazione.pdf soluzioni.pdf

.PHONY: all clean distclean

all: $(TARGETS)

esercitazione.pdf: esercitazione.tex $(DEPS)
	$(LATEXMK) $(LATEXMKFLAGS) esercitazione.tex

soluzioni.pdf: soluzioni.tex $(DEPS)
	$(LATEXMK) $(LATEXMKFLAGS) soluzioni.tex

clean:
	$(LATEXMK) -c esercitazione.tex soluzioni.tex || true
	rm -f *.aux *.log *.out *.fls *.fdb_latexmk

distclean: clean
	rm -f $(TARGETS)
