# 17 — Heap-based buffer overflow: `heap-one` (tecnica delle slide NON riprodotta — vedi sotto)

Sorgente: `src/17-heap-one/heap-one.c` — copia **invariata** di
`phoenix/heap-one` (exploit.education), vedi "Lezione 6 - HEAP-BASED
Buffer OVERFLOW.pptx" (slide "Continuaiamo ad analizzare con GDB" →
"Mettiamo insieme i pezzi"). Due `struct heapStructure { int priority;
char *name; }`, ciascuna con `name` allocato via `malloc(8)`;
`strcpy(i1->name, argv[1])` e `strcpy(i2->name, argv[2])` senza controllo
dei limiti. `winner()` esiste ma **non è mai chiamata dal programma**:
l'obiettivo delle slide è dirottare l'esecuzione verso di lei
sovrascrivendo, tramite l'overflow da `i2->name`, un indirizzo di ritorno
sullo **stack**.

## Cosa succede qui, verificato

- La corruzione **avviene**: un `argv[1]`/`argv[2]` sufficientemente
  lungo (oltre gli 8 byte di `name`) sovrascrive la struttura adiacente e
  fa crashare il programma (`SIGSEGV`, verificato con un pattern
  `cyclic()` + analisi del corefile) — il livello **non** è "non
  vulnerabile", il bug c'è ed è lo stesso del sorgente originale.
- La tecnica **esatta** delle slide (calcolare la distanza tra
  l'indirizzo del buffer su cui metteva lo shellcode, `0x7fffffef6030`
  nella demo, e l'indirizzo di ritorno sullo stack da sovrascrivere,
  `0x7fffffffe668`) si basa su un fatto specifico di quella VM Phoenix:
  **heap e stack erano vicini in memoria** (circa 120 KB di distanza),
  così un overflow di `~550` byte da un buffer heap riusciva comunque a
  raggiungere lo stack.
- **Su questa vulnbox (Debian bookworm, glibc) questo non è vero**:
  verificato con un programma di diagnostica minimo (stessa sequenza di
  `malloc()`, variabile locale sullo stack) che l'heap finisce verso
  `0x0804...` e lo stack verso `0x4080...` — **oltre 1 GB di distanza**,
  non 120 KB. Un overflow da un buffer di 8 byte non ha nessuna
  possibilità realistica di raggiungere lo stack su questo layout di
  memoria: prima incontra (ed eventualmente corrompe fino al crash) solo
  altra memoria dell'arena heap.

## Perché non è stato forzato un exploit alternativo

Sovrascrivere `winner()` qui richiederebbe una tecnica strutturalmente
diversa da quella della lezione (es. corrompere i metadati dell'arena
glibc per influenzare un `malloc()` successivo con un attacco
tcache/unsorted-bin moderno) — non quello che la slide insegna, e non
verificabile in modo affidabile senza uno studio a parte. Per coerenza
con le istruzioni del progetto ("niente inventato": le domande/esempi
derivano dalle slide, non da tecniche aggiunte di proprio conto), questo
esempio resta **documentato come limite noto**, sulla falsariga di
`04-rop` non portato ad arm64: nessun `exploit.py` per nessuna
architettura, nessuna fabbricazione di un risultato non verificato.

## Dimostrazione in aula possibile comunque

Il crash stesso (corruzione di memoria via heap overflow) resta
dimostrabile e didatticamente valido:

```sh
heap-one AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBB
# Segmentation fault
```

Utile per mostrare che un `malloc(8)` seguito da `strcpy()` senza
controllo è comunque exploitabile in linea di principio — il "dove
esattamente porta la corruzione" dipende dal layout di memoria del
sistema, un punto didattico in sé (collegabile alla sezione ASLR/layout
già trattata in `14-countermeasure-aslr`).
