# Makefile - compila i documenti d'esame (classe exam)
# Richiede una distribuzione LaTeX con latexmk, classe exam e pacchetto listings.
# 'make' produce esame.pdf e soluzioni.pdf; 'make clean' rimuove gli ausiliari.

LATEXMK := latexmk
LATEXMKFLAGS := -pdf -interaction=nonstopmode -halt-on-error
DEPS := preambolo.tex elenco.tex $(wildcard domande/*.tex)
TARGETS := esame.pdf soluzioni.pdf

.PHONY: all clean distclean

all: $(TARGETS)

esame.pdf: esame.tex $(DEPS)
	$(LATEXMK) $(LATEXMKFLAGS) esame.tex

soluzioni.pdf: soluzioni.tex $(DEPS)
	$(LATEXMK) $(LATEXMKFLAGS) soluzioni.tex

clean:
	$(LATEXMK) -c esame.tex soluzioni.tex || true
	rm -f *.aux *.log *.out *.fls *.fdb_latexmk *.tmp

distclean: clean
	rm -f $(TARGETS)
