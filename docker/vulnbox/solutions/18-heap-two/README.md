# 18 — Heap-based buffer overflow: puntatore stantio (`heap-two`)

Sorgente: `src/18-heap-two/heap-two.c` — copia **invariata** di
`phoenix/heap-two` (exploit.education), vedi "Lezione 6 - HEAP-BASED
Buffer OVERFLOW.pptx". Programma interattivo (comandi da stdin) con due
variabili globali: `auth` (puntatore a `struct auth { char name[32]; int
auth; }`) e `service` (`char *`). `login` stampa il messaggio di successo
se `auth` non è nullo **e** `auth->auth` (offset 32 dentro lo stesso
chunk) non è zero — ma nulla nel programma imposta mai quel campo.

## Dimostrazione in aula (`exploit.py`, qualsiasi variante)

Stessa sequenza della slide "L'exploit":

```sh
heap-two
auth A            # alloca e inizializza auth (36 byte: 32 nome + 4 auth)
reset              # free(auth): il puntatore resta "stantio"
serviceBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB   # strdup() riusa lo stesso chunk appena liberato
login              # auth punta ora alla stringa di service: "already!"
```

`service` (via `strdup`) ottiene lo stesso chunk appena liberato da
`reset` — immediato, perché è un riuso **LIFO** sia su un fastbin
dlmalloc/glibc classico sia sul tcache delle glibc moderne (qui: Debian
bookworm). Una stringa di 36+ caratteri scrive un byte non-nullo anche
all'offset 32 (il campo `auth->auth`, ora sovrapposto al contenuto di
`service`), quindi la condizione di `login` risulta vera.

`exploit.py` automatizza la sequenza sopra via `pwntools`: nessun
indirizzo o offset di memoria è coinvolto (la vulnerabilità è sul
*contenuto*, non sul controllo di flusso), quindi lo script non deve
ricavare nulla dinamicamente oltre a leggere l'output. Nota tecnica: il
programma non chiama `fflush()` tra un prompt e l'altro — su un pipe
(non un tty) `stdout` è bufferizzato a blocchi, quindi lo script invia
tutti i comandi in un colpo solo e chiude lo stdin (`shutdown("send")`)
per far uscire `heap-two` dal suo `while(1)` e scaricare l'output
bufferizzato, invece di leggere riga per riga.

## Varianti amd64-64 bit e arm64 (`exploit-x64.py`, `exploit-arm64.py`)

Identiche a `exploit.py`, nessuna modifica: la tecnica non dipende da
indirizzi o bitness, solo dalle dimensioni dei campi della struct
(`name[32]` + `auth` a 4 byte, costanti su tutte e tre le varianti).
Verificato su `~student/bin/x64/heap-two` e `~student/bin/arm64/heap-two`.
