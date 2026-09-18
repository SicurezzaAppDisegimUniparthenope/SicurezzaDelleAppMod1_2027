# 05 — Jump Oriented Programming (nota concettuale)

A differenza degli altri quattro, per JOP **non c'è un binario dedicato**
in `src/`: un dispatcher-gadget JOP affidabile richiede gadget `jmp
*reg`/`jmp *(mem)` costruiti ad hoc, ed è più rischioso da garantire
funzionante rispetto agli altri esempi (che si basano su tecniche più
standard: format string, `ret2libc`, ROP via funzioni con simboli propri).
Prima di usarlo in aula va comunque verificato per davvero dentro
`vulnbox` — vedi la nota in fondo.

## Cosa mostrare comunque a lezione (slide SS_3.3)

- Riprendere `rop.c`/`rop` (esempio 04) e la sua catena ROP già funzionante
  come punto di partenza per il confronto concettuale slide 10:
  - ROP: la catena di gadget sta **sullo stack**, ogni gadget termina con
    `ret`, il controllo richiede `EIP` + `ESP`.
  - JOP: la catena sta in una **dispatch table** in un'area dati qualsiasi
    (stack, heap, globali), ogni gadget termina con `jmp` indiretto, un
    "gadget dispatcher" fa avanzare un puntatore verso la tabella; serve
    `EIP` + un registro/locazione di memoria per il dispatcher, non
    necessariamente `ESP`.
- Discutere perché JOP nasce come *contromisura alle contromisure* per ROP
  (slide 6-7): tecniche di rilevamento basate sull'osservare sequenze di
  `ret`/`pop` verso lo stesso'indirizzo non si accorgono di una catena
  basata su `jmp` indiretti.

## Se si vuole comunque costruire un esempio funzionante

Prima di usarlo con gli studenti, va scritto un binario con gadget "jmp"
espliciti (tipicamente funzioni `__attribute__((naked))` con inline asm) e
un dispatcher gadget, **compilato e testato per davvero dentro
`vulnbox`** (registri/convenzioni possono comportarsi in modo sottile e
diverso da quanto ci si aspetta in teoria) prima di considerarlo materiale
da esercitazione.
