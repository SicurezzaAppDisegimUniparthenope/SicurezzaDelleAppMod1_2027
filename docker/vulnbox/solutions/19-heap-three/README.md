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

## Perché serve una malloc diversa da quella di sistema (verificato)

La glibc di Debian bookworm (2.36) ha controlli di integrità su
`unlink()` (ossia sul passo cruciale di questo attacco) che bloccano
esattamente la tecnica delle slide. **Soluzione adottata** (decisione
dell'utente in questa sessione): compilare `heap-three` linkato
staticamente contro la **stessa** `malloc-2.7.2.c` citata nel commento
originale di Phoenix (`src/19-heap-three/malloc-2.7.2.c`, scaricata da
<https://gee.cs.oswego.edu/pub/misc/malloc-2.7.2.c>, **SHA1 verificato
uguale** a quello nel commento: `407329d164e4989b59b9a828760acb720dc5c7db`).
`build.sh` compila quel file come oggetto e lo linka insieme a
`heap-three.c` (nessuna flag `USE_DL_PREFIX`: esporta `malloc`/`free`
con i nomi standard, sovrascrivendo quelli di libc per interposizione di
simboli — stessa tecnica di collegamento dichiarata dal commento
originale di Phoenix). **Verificato**:

- Il binario risultante usa davvero questa malloc (`nm` mostra `malloc`/
  `free` definiti nel binario stesso, non importati da `libc.so.6`).
- La macro `unlink()` di `malloc-2.7.2.c` **non ha controlli di
  integrità** (nessun check `P->fd->bk == P`, introdotto nelle glibc
  moderne dopo CVE storiche): esattamente la condizione che serve.
- Il binario compila ed esegue correttamente (`dynamite failed?`,
  comportamento base verificato).

## Stato dell'exploit: tecnica documentata, script NON completato in questa sessione

L'attacco (dalle slide "L'idea dell'exploit"/"L'exploit", riassunto):

1. **Chunk A**: 4 byte di padding (NOP) + shellcode.
2. **Chunk B**: padding (32 byte) + `prev_size` e `size` **falsi** per
   il Chunk C, costruiti così che `free(c)` creda che il chunk
   "precedente" (in realtà dati di B sotto controllo dell'attaccante)
   sia libero e vada consolidato.
3. **Chunk C**: 4 byte di padding + due parole da 4 byte interpretate da
   `unlink()` come `P->fd` e `P->bk` del chunk falso: scegliendo
   `P->fd = GOT(puts) - 4` e `P->bk = <indirizzo verso cui puntare>`,
   la macro `unlink` (`FD->bk = BK; BK->fd = FD;`) scrive `P->bk`
   all'indirizzo GOT di `puts()` — la `printf("dynamite failed?\n")`
   finale (che gcc traduce in una `call puts@plt`, verificato via
   `objdump -R`) finisce quindi per saltare lì invece che alla vera
   `puts()`.

Il dettaglio delicato (via che le slide risolvono con "uno shellcode che
spinge l'indirizzo sullo stack, poi `ret`", invece di scrivere
direttamente l'indirizzo di `winner()`): la stessa `unlink()` esegue
*anche* una seconda scrittura (`FD->bk = BK`, cioè 4 byte a
`P->fd + 4`) come effetto collaterale sulla destinazione scelta per
`P->bk` — se si punta `P->bk` direttamente a `winner()`, quei 4 byte di
`winner()` stesso vengono corrotti prima ancora di poterla eseguire.
Per questo l'attacco reale punta `P->bk` all'inizio del **Chunk A**
(dove l'effetto collaterale sovrascrive solo i 4 byte di padding NOP,
non il payload vero) e lo shellcode nel Chunk A è quello che poi salta a
`winner()`.

**Non è stato portato a termine in questa sessione** (offset esatti del
payload, verifica bit-a-bit con un corefile) — a differenza degli altri
3 esempi di questa lezione, qui non c'è ancora uno `exploit.py`
verificato. La costruzione del binario/toolchain sopra **è** verificata
e pronta; resta da costruire e testare il payload a 3 chunk descritto.
Prossimo passo naturale per chi riprende il lavoro: ripetere l'analisi
con GDB della slide ("Analisi" — breakpoint dopo ogni `malloc()`/`free()`,
`vmmap`) su questo binario per leggere gli offset reali tra i 3 chunk
(probabilmente diversi da quelli della VM Phoenix originale, essendo
un'allocatore diverso anche se stessa versione) prima di costruire il
payload.
