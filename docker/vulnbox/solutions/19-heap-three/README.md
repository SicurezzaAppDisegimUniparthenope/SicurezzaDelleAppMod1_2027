# 19 — Heap-based buffer overflow: attacco a `unlink()` (`heap-three`)

Sorgente: `src/19-heap-three/heap-three.c` — copia **invariata** di
`phoenix/heap-three` (exploit.education), vedi "Lezione 6 - HEAP-BASED
Buffer OVERFLOW.pptx" (dalla slide "Come funziona l'heap - malloc" a
"L'exploit"). 3 chunk di 32 byte (`a`, `b`, `c`), ciascuno riempito via
`strcpy(argv[N])` senza controllo dei limiti, liberati in ordine inverso
(`c`, `b`, `a`). Il commento originale del sorgente dichiara il livello
"linked against... malloc-2.7.2.c... Doug Lea Malloc" — **non** la libc
di sistema.

**Solo i386**: sia il commento originale ("this level is solvable on
Linux i386 easily enough, as for other architectures, it may not be
possible") sia la lezione stessa trattano solo questa variante — nessun
binario né script per amd64-64/arm64.

## Perché serve una malloc diversa da quella di sistema

La glibc di Debian bookworm (2.36) ha controlli di integrità su
`unlink()` che bloccano esattamente la tecnica delle slide. **Soluzione
adottata**: compilare `heap-three` linkato staticamente contro la
**stessa** `malloc-2.7.2.c` citata nel commento originale di Phoenix
(`src/19-heap-three/malloc-2.7.2.c`, scaricata da
<https://gee.cs.oswego.edu/pub/misc/malloc-2.7.2.c>, **SHA1 verificato
uguale** a quello nel commento: `407329d164e4989b59b9a828760acb720dc5c7db`).
`build.sh` compila quel file come oggetto e lo linka insieme a
`heap-three.c` (nessuna flag `USE_DL_PREFIX`: esporta `malloc`/`free`
con i nomi standard, sovrascrivendo quelli di libc per interposizione di
simboli). Verificato: il binario risultante usa davvero questa malloc
(`nm` mostra `malloc`/`free` definiti nel binario stesso), e la macro
`unlink()` di `malloc-2.7.2.c` non ha controlli di integrità.

## L'exploit (`exploit.py`) — **verificato funzionante, eseguito più volte**

A differenza degli altri esempi di questa lezione, questo **non è** uno
script argv-based "usa e getta": serve correggere, con un payload a 3
chunk, alcuni campi interni dell'allocatore (soglia reale del fastbin,
bit `PREV_INUSE` del chunk "successivo") che non sono raggiungibili
dall'esterno del processo senza una sonda live. `exploit.py` usa quindi
l'**API Python di GDB** per scrivere il payload direttamente in memoria
con breakpoint dopo ogni `malloc()`/prima di ogni `free()` — nello
spirito della demo della slide stessa (che usa GDB per lo stesso
motivo). Uso:

```sh
gdb -q --batch -x exploit.py
```

Nessun indirizzo è hardcoded: quello di `winner()` si legge dal binario
(debug info), quello GOT di `puts()` da `objdump -R`, e gli indirizzi
delle chiamate a `malloc()`/`free()` dentro `main()` dal disassembly —
tutti ricavati a runtime, quindi lo script resta valido anche se il
binario viene ricompilato con offset leggermente diversi. **Non serve
disabilitare l'ASLR**: ogni indirizzo (chunk, `argv[1]`) viene letto
dallo stesso processo in esecuzione sotto gdb, mai riusato tra lanci
diversi — verificato funzionante sia con `setarch i386 -R` sia con
ASLR realmente attiva.

### La tecnica passo passo

1. **Chunk A**: contiene un piccolo trampolino macchina (`push
   <winner>; ret`, 6 byte) scritto sopra `argv[1]` — eseguito più avanti
   quando `puts()` verrà dirottato lì. (Il trampolino vive sullo *stack*,
   dove risiedono i byte di `argv[1]`: l'heap di questa toolchain
   **non è eseguibile** nemmeno con `-z execstack`, verificato — quel
   flag riguarda solo il segmento `PT_GNU_STACK`, non l'intero processo
   come nei vecchi binari senza quel segmento. Mettere il trampolino
   direttamente sull'heap, come suggerirebbe una lettura superficiale
   della slide, qui farebbe SIGSEGV al salto.)
2. **Chunk B**: i suoi primi 8 byte diventano, agli occhi di `free()`,
   i campi `fd`/`bk` di un "chunk libero precedente" fittizio `P`
   (`P = b_chunkheader`). Si scrive `P->fd = argv1` (l'indirizzo del
   trampolino) e `P->bk = GOT(puts) - 8`.
3. **Chunk C**: il suo header viene corrotto (via quello che nella
   slide sarebbe l'overflow da B, qui scritto direttamente per
   chiarezza) con `prev_size` pari esattamente alla distanza fino a
   `b_chunkheader`, e una `size` fittizia **sopra la vera soglia
   `max_fast`** di questo binario (letta a runtime da `av_.max_fast`:
   72 byte, non i 64 "di manuale" — la differenza è dovuta al
   `request2size()` interno di dlmalloc) con il bit `PREV_INUSE` a 0.
   Una size fittizia *sotto* quella soglia manda il chunk in un
   **fastbin** invece che nel percorso di consolidamento che chiama
   `unlink()` — il primo ostacolo reale incontrato costruendo questo
   exploit.
4. `free(c)`: vedendo `PREV_INUSE` a 0, dlmalloc tratta `P` come un
   vero chunk libero adiacente e chiama `unlink(P, bck, fwd)`, che
   esegue `FD->bk = BK` (scrive `GOT(puts)-8` a `argv1+12`, innocuo: è
   dentro al trampolino/padding sullo stack) e `BK->fd = FD` (scrive
   l'indirizzo del trampolino esattamente a `GOT(puts)-8+8 =
   GOT(puts)`). **Qui avviene l'overwrite della GOT.**

Il resto dello script (commentato riga per riga) ripara alcuni effetti
collaterali reali della consolidazione per evitare `SIGSEGV` *dopo*
l'overwrite, prima di arrivare alla `printf()` finale:

- `free(c)` fonde (realmente, nell'allocatore) B+C in un chunk unico,
  riscrivendo l'header di B — ma il programma chiama comunque `free(b)`
  subito dopo come se fosse indipendente. Si ripristina l'header di B a
  un valore piccolo "in uso" (come l'originale) perché prenda la via
  semplice del fastbin.
- Il chunk "successivo" a quello fittizio (dopo C) cade nella
  wilderness (memoria mai scritta, letta come `0`): senza intervento,
  `free()` la tratterebbe come un altro chunk libero da fondere e
  tenterebbe un `unlink()` su `fd=bk=0`, cioè un null-deref. Si forza il
  suo bit `PREV_INUSE` a 1.
- La stessa verifica si ripete più avanti (alla primissima allocazione
  del buffer `stdio` interno di `printf()`, **dentro `winner()` stessa**,
  quando `malloc_consolidate()` ripercorre i fastbin di A e B): va
  ri-applicata la stessa correzione sull'header di C.

Nessuna di queste correzioni altera l'obiettivo pedagogico (l'overwrite
della GOT via `unlink()`, il cuore della lezione): sono conseguenze
inevitabili di un vero allocatore che, dopo l'exploit, continua a girare
fino alla `printf()` finale invece di fermarsi lì.

### Risultato

```
GOT(puts) sovrascritta con il trampolino: 0xffffdf13
Level was successfully completed at @ 1793182214 seconds past the Epoch
[Inferior 1 (process 1183) exited normally]
```

La riga `Level was successfully completed...` è il messaggio di
`winner()` — eseguito al posto di `puts()`, confermato anche da un
backtrace (`winner() at heap-three.c:47` → `main() at heap-three.c:66`)
preso durante lo sviluppo di questo script. Verificato più volte di
seguito, sia con ASLR disabilitata sia con ASLR realmente attiva.
