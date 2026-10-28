# 16 — Heap-based buffer overflow: function-pointer overwrite (`heap-zero`)

Sorgente: `src/16-heap-zero/heap-zero.c` — copia **invariata** di
`phoenix/heap-zero` (exploit.education), vedi "Lezione 6 - HEAP-BASED
Buffer OVERFLOW.pptx". Due `malloc()`: `d` (64 byte, nome) e `f` (64
byte, con un puntatore a funzione `fp` inizializzato a `nowinner`).
`strcpy(d->name, argv[1])` non ha controllo dei limiti: un argomento più
lungo di `sizeof(struct data)` trabocca nel chunk successivo e sovrascrive
`f->fp`, chiamato subito dopo (`f->fp()`).

## Dimostrazione in aula (i386, `exploit.py`)

Stesso procedimento delle slide (`nm`/`objdump` per l'indirizzo di
`winner()`, poi calcolo della distanza tra `d` e `f->fp` da un lancio di
prova):

```sh
nm ~student/bin/i386/heap-zero | grep winner
./heap-zero AAAAAAAA                      # legge "data is at X, fp is at Y"
python3 -c 'print(Y - X)'                  # distanza (80 su questa build)
python3 exploit.py
```

Nessun offset/indirizzo è hardcoded nello script: l'offset si ricava da
un lancio "usa e getta" (lo stesso principio della demo manuale sopra),
l'indirizzo di `winner()` si legge dal binario via `pwntools ELF` (sempre
fisso: binario `-no-pie`).

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/heap-zero`)

Le slide, per la variante a 64 bit, introducono un'indirezione
("mettiamo un breve shellcode... push ADDR; ret") perché l'indirizzo di
`winner()` contiene byte nulli che troncherebbero la `strcpy()`. **Non
è servita** su questa build: l'indirizzo di `winner()` qui finisce
comunque con diversi byte `0x00` finali (è `< 2**32`), ma dato che
`f->fp` è una chiamata a funzione qualsiasi, può puntare **direttamente**
a `winner()` in `.text` — nessuna esecuzione di codice sull'heap
necessaria, nessuna indirezione. Il punto delle slide (byte nulli che
troncano la stringa) resta comunque vero ed è gestito così: si rimuovono
esplicitamente i NUL dal payload invece di affidarsi a bash (la demo
usa `$(python heap0_64.py)`, con l'avviso "command substitution: ignored
null byte in input" — bash li rimuove da sola). `strcpy()` scrive comunque
il proprio byte terminatore subito dopo l'ultimo byte copiato, e il resto
del valore voluto coincide con memoria heap appena allocata (quindi già a
zero) — stesso principio, reso esplicito invece di implicito in bash.
Siccome il payload può contenere NUL, `pwntools.process()` si rifiuta di
avviarlo (sicurezza): lo script usa `subprocess` diretto.

**Verificato anche sotto QEMU** (host arm64, variante amd64 emulata): il
tentativo iniziale con l'indirezione "push ADDR; ret" **fallisce** qui
con SIGSEGV — analizzando il corefile generato da QEMU, l'heap di questa
toolchain (Debian bookworm, glibc) **non è eseguibile** nemmeno con `-z
execstack` (quel flag imposta solo lo stack a RWE via `PT_GNU_STACK`, non
l'intero processo come nei vecchi binari senza quel segmento): da qui la
scelta di sovrascrivere `f->fp` direttamente con `winner()`, che non
richiede eseguire nulla sull'heap.

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/heap-zero`)

Identica a x64 (stesso schema, nessuna indirezione necessaria). L'unica
differenza osservata: su questa build **l'ASLR randomizza davvero**
l'heap (a differenza della variante amd64 sotto QEMU, dove non
randomizza), ma lo script **non ne risente**: l'unico indirizzo assoluto
usato è quello di `winner()` (fisso, binario `-no-pie`), l'offset fino a
`f->fp` è una dimensione di chunk (non un indirizzo), ricavata di nuovo
da un lancio "usa e getta" indipendente da quello dell'exploit finale.
