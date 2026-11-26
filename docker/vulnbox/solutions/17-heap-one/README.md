# 17 — Heap-based buffer overflow: `heap-one` (riprodotto su Phoenix, NON sulla vulnbox)

Sorgente: `src/17-heap-one/heap-one.c` — copia **invariata** di
`phoenix/heap-one` (exploit.education), vedi "Lezione 6 - HEAP-BASED
Buffer OVERFLOW.pptx" (slide "Continuaiamo ad analizzare con GDB" →
"Mettiamo insieme i pezzi"). Due `struct heapStructure { int priority;
char *name; }`, ciascuna con `name` allocato via `malloc(8)`;
`strcpy(i1->name, argv[1])` e `strcpy(i2->name, argv[2])` senza controllo
dei limiti. `winner()` esiste ma **non è mai chiamata dal programma**:
l'obiettivo delle slide è dirottare l'esecuzione verso di lei
sovrascrivendo, tramite l'overflow da `i1->name`, prima il **puntatore
dati** `i2->name` e — con la seconda `strcpy` — un indirizzo di ritorno
sullo **stack**.

> **A differenza di tutti gli altri esempi di questa cartella, l'exploit
> di `heap-one` NON gira sulla vulnbox del corso.** Lo script
> [`exploit-phoenix.py`](exploit-phoenix.py) gira su un'istanza **Phoenix**
> (exploit.education, binario `/opt/phoenix/amd64/heap-one`), non sul
> container vulnbox. Il *perché* è il punto didattico centrale di questo
> livello ed è spiegato qui sotto: la tecnica delle slide dipende da un
> layout di memoria (ASLR spento, heap e stack con indirizzi noti) che la
> vulnbox moderna non ha e Phoenix sì.

## Perché NON sulla vulnbox (verificato)

- La corruzione **avviene** anche sulla vulnbox: un `argv[1]`/`argv[2]`
  sufficientemente lungo (oltre gli 8 byte di `name`) sovrascrive la
  struttura adiacente e fa crashare il programma (`SIGSEGV`, verificato
  con un pattern `cyclic()` + analisi del corefile) — il livello **non**
  è "non vulnerabile", il bug c'è ed è lo stesso del sorgente originale.
- La tecnica **esatta** delle slide (calcolare la distanza tra
  l'indirizzo del buffer su cui si mette lo shellcode e l'indirizzo di
  ritorno sullo stack da sovrascrivere) si basa su un fatto specifico
  della VM Phoenix originale: **heap e stack erano vicini in memoria** e
  **l'ASLR era spento**, quindi gli indirizzi erano fissi e noti a priori.
- **Su questa vulnbox (Debian bookworm, glibc) questo non è vero**:
  verificato con un programma di diagnostica minimo (stessa sequenza di
  `malloc()`, variabile locale sullo stack) che l'heap finisce verso
  `0x0804...` e lo stack verso `0x4080...` — **oltre 1 GB di distanza**.
  Un overflow da un buffer di 8 byte non ha nessuna possibilità realistica
  di raggiungere lo stack su questo layout di memoria: prima incontra (ed
  eventualmente corrompe fino al crash) solo altra memoria dell'arena heap.
  In più l'**ASLR è attivo**: anche la distanza, oltre a essere enorme,
  cambia a ogni esecuzione.
- **Confermato anche su host x86_64 reale** (vulnbox nativa, nessuna
  emulazione QEMU): stesso programma diagnostico, stesso binario i386 —
  heap verso `0x0809...`, stack verso `0xffca...`, **quasi 4 GB di
  distanza**, anche peggiore che sotto emulazione. Non è quindi un
  artefatto dell'emulazione: è una differenza strutturale tra il layout di
  memoria dei kernel Linux moderni (stack molto in alto) e quello della VM
  Phoenix originale (kernel ~2011, layout pre-ASLR-moderna con stack molto
  più vicino all'heap).

## Exploit funzionante su Phoenix (`exploit-phoenix.py`)

Per riprodurre la tecnica delle slide *tale e quale* serve l'ambiente per
cui è pensata: un'istanza **Phoenix** (exploit.education) con **ASLR
disattivato** (`/proc/sys/kernel/randomize_va_space = 0`), dove gli
indirizzi sono fissi. Lo script usa il binario a 64 bit
`/opt/phoenix/amd64/heap-one` (non-PIE, `winner()` a `0x400af3`).

Catena dell'attacco (identica alle slide):

1. `strcpy(i1->name, argv[1])` trabocca da `i1->name` (`0x7ffff7ef6030`,
   fisso con ASLR off) e **sovrascrive il puntatore `i2->name`** (a offset
   `0x28` = 40 byte) con l'indirizzo del return address di `main` sullo
   stack (`0x7fffffffed78`).
2. `strcpy(i2->name, argv[2])` scrive quindi `argv[2]` — l'indirizzo del
   buffer-shellcode (`0x7ffff7ef6030`) — **dentro il return address di
   `main`**: un overflow di *dati* (un puntatore) diventa controllo del
   *flusso* (write-what-where verso lo stack).
3. Al `ret` di `main` l'esecuzione salta nello shellcode sull'heap, che a
   sua volta salta a `winner()`.

Dettagli di `exploit-phoenix.py`:

- **Shellcode null-free**: l'indirizzo di `winner()` (`0x400af3`)
  contiene byte nulli che troncherebbero la `strcpy()`; invece di passarlo
  diretto si usa un breve shellcode senza NUL che lo ricostruisce nei
  registri e ci salta (`xor eax,eax; mov al,0x40; shl eax,16; mov
  ax,0x0af3; jmp rax`) — stessa idea dell'indirezione "push ADDR; ret"
  delle slide, resa null-free.
- **Indirizzi fissi perché ASLR off**: `winner()` e il buffer heap sono
  deterministici. L'unico valore che dipende da argv/env del lancio è il
  return address di `main`: lo script prova prima il valore noto
  (`0x7fffffffed78`, lancio diretto con env vuoto) e, nel caso cambiasse,
  lo cerca in una finestra ristretta — lo stesso metodo con cui è stato
  trovato, nessun indirizzo "magico" non spiegato.
- **Compatibilità Python**: l'immagine Phoenix monta Python 3.5, quindi lo
  script evita f-string e usa `subprocess.run(..., stdout=PIPE)` (non
  `capture_output`).

Esecuzione (**sul guest Phoenix**, dove l'ASLR è spento — non sulla
vulnbox):

```sh
python3 exploit-phoenix.py
```

Output atteso (verificato):

```
[+] RET (return address di main) = 0x7fffffffed78
[+] winner() @ 0x400af3 via shellcode heap @ 0x7ffff7ef6030
Congratulations, you've completed this level @ <epoch> seconds past the Epoch
```

Dopo `winner()` il programma termina con "Illegal instruction": lo
shellcode ci è *saltato* (non chiamato), quindi al termine di `winner()`
non c'è un return address valido — irrilevante, la stampa di successo è già
avvenuta.

## Dimostrazione in aula possibile anche sulla vulnbox (il crash)

Dove non è disponibile un'istanza Phoenix, il crash stesso (corruzione di
memoria via heap overflow) resta dimostrabile e didatticamente valido
sulla vulnbox:

```sh
heap-one AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA BBBB
# Segmentation fault
```

Utile per mostrare che un `malloc(8)` seguito da `strcpy()` senza
controllo è comunque exploitabile in linea di principio — il "dove
esattamente porta la corruzione" dipende dal layout di memoria del
sistema, un punto didattico in sé (collegabile alla sezione ASLR/layout
già trattata in `14-countermeasure-aslr`): su Phoenix (ASLR off, heap/stack
vicini) si arriva a `winner()`, sulla vulnbox moderna (ASLR on, >1 GB di
distanza) si arriva solo al crash.

## Nota

Nessun `exploit.py`/`exploit-x64.py`/`exploit-arm64.py` per la vulnbox:
su quel sistema la tecnica non è riproducibile (vedi sopra) e forzare un
exploit alternativo (es. attacco tcache/unsorted-bin moderno) sarebbe una
tecnica *diversa* da quella della lezione — coerentemente con "niente
inventato", non la si aggiunge. L'unico script, `exploit-phoenix.py`,
dichiara esplicitamente nel proprio header di girare su Phoenix e perché.
