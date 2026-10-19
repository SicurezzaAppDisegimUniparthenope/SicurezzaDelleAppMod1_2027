# 05 — Jump Oriented Programming (`jop`)

Sorgente: `src/05-jop/jop.c` — binario compilato in
`~student/bin/i386/jop` (32 bit, come nelle slide), `~student/bin/x64/jop`
(64 bit) e `~student/bin/arm64/jop` (AArch64 nativo). Slide SS_3.3;
riferimento accademico: Bletsch, Jiang, Freeh, Smith — *"Jump-Oriented
Programming: A New Class of Code-Reuse Attack"* (ASIACCS 2011).

> **Nota storica.** In una sessione precedente qui c'era solo una nota
> concettuale: "per JOP non c'è un binario dedicato, un dispatcher-gadget
> affidabile è più rischioso da garantire". Ora l'esempio **esiste ed è
> verificato** (vedi "Come è stato costruito" e "Difficoltà incontrate").
> È costruito con lo stesso spirito di `04-rop`: i "gadget" non sono
> sequenze rastrellate nel binario (quelle sì fragili) ma **funzioni
> intere scritte apposta**, che terminano con un salto indiretto invece
> che con `ret`.

## L'idea (confronto ROP ↔ JOP, slide 6-10)

Il risultato finale è identico a `04-rop`: costruire `"/bin/sh"` nel buffer
globale `command` ed eseguire `system(command)` tramite tre "gadget"
(`g_bin` → `g_sh` → `g_exec`). La differenza è **come** la catena viene
eseguita:

- **ROP**: la catena di gadget sta **sullo stack**, ogni gadget termina con
  `ret`, il controllo richiede `EIP` + `ESP` (è `ESP` a fare da "program
  counter" della catena).
- **JOP**: la catena sta in una **dispatch table** (un'area dati qualsiasi;
  qui nello stack, nel payload), ogni gadget termina con un **salto
  indiretto** verso un **dispatcher gadget** che fa avanzare un puntatore
  nella tabella. Il "program counter" della catena è un **registro
  dedicato** (`EDI` su i386, `R12` su x86-64), **non** `ESP`.

Perché JOP esiste (slide 6-7): è una *contromisura alle contromisure* del
ROP. I rilevatori che osservano sequenze anomale di `ret` verso lo stesso
indirizzo non vedono una catena fatta di `jmp` indiretti.

## Come è stato costruito (`src/05-jop/jop.c`)

Lo stesso sorgente serve i386 e x86-64 (le slide usano x86); l'asm dei
gadget è guardato per architettura con `#if defined(__i386__) /
__x86_64__)`. I gadget sono funzioni `__attribute__((naked))` con asm
inline:

- `dispatcher` — il cuore del JOP:
  `mov (PC)->tmp ; PC += wordsize ; jmp *tmp` (i386: `EDI`/4 byte;
  x86-64: `R12`/8 byte).
- `g_bin` / `g_sh` — scrivono `"/bin"` / `"/sh\0"` in `command`, poi
  `jmp dispatcher`.
- `g_exec` — `system(command)`, poi `jmp dispatcher` (non prosegue: la
  shell è interattiva).
- `jop_start` — trampolino d'ingresso: l'overflow ritorna qui; carica il
  registro-PC **dallo stack pointer** (`mov %esp,%edi` / `mov %rsp,%r12`) e
  salta al dispatcher.

**Scelta chiave — niente indirizzo di stack assoluto.** La dispatch table
vive nel payload, subito dopo il return address. `jop_start` la individua
copiando lo stack pointer nel registro-PC: al suo ingresso quel registro
punta già al primo elemento della tabella. Così l'exploit ha bisogno
**solo dell'offset** dell'overflow, non di un indirizzo di stack assoluto
(niente leak, niente corefile). Questo è ciò che rende l'esempio
deterministico e verificabile anche su host nativo (vedi difficoltà #2).

## Script

```sh
python3 exploit.py        # i386   (~student/bin/i386/jop)
python3 exploit-x64.py    # x86-64 (~student/bin/x64/jop)
python3 exploit-arm64.py  # arm64  (~student/bin/arm64/jop)
```

Entrambi: ricavano l'offset, leggono gli indirizzi dei gadget dai simboli
(`ELF` di pwntools: binario `-no-pie`, non stripped), costruiscono la
dispatch table `[&g_bin, &g_sh, &g_exec]` subito dopo `&jop_start`, e
aprono una shell. Verificato: `id` → `uid=...(vulnbox)`.

## Difficoltà incontrate (ed esiti)

1. **Un solo `.c` per due architetture con asm inline.** A differenza
   degli altri esempi (C puro), qui i gadget sono asm. Risolto guardando
   i blocchi per `__i386__` / `__x86_64__`; su arch non-x86 il file
   compila come nota esplicativa (vedi arm64 sotto). Su x86-64 il "PC"
   della catena è **`R12`** (callee-saved e **non** registro di
   argomento): usare `RDI` lo farebbe sovrascrivere da `g_exec` quando
   passa il primo argomento a `system()`.

2. **Niente corefile automatico su host x86 NATIVO.** Gli exploit di
   `04-rop`/`08-shellcode` ricavano offset (e indirizzi) dal **corefile**
   del crash — che però esiste solo perché su Apple Silicon i386/x64
   girano sotto **QEMU user-mode** (è QEMU a scriverlo). Su un host x86
   nativo (dove questo esempio è stato verificato) i binari girano
   nativamente e il `core_pattern` punta a `systemd-coredump`, non
   disponibile/scrivibile nel container — **stesso limite già documentato
   per arm64 nativo**. Soluzione: l'offset si ricava allegando `gdb`
   (`-p PID`) al processo lanciato da pwntools e leggendo il crash, come
   negli `exploit-arm64.py`. Grazie alla scelta "PC-da-SP" (sopra) serve
   *solo* l'offset, quindi questa via basta — non serve un indirizzo
   assoluto coerente col processo reale.

3. **x86-64: `ret` verso indirizzo non canonico ⇒ `#GP`, non il target.**
   Durante la ricerca dell'offset il pattern ciclico (`0x6161...`) non è
   un indirizzo *canonico* a 64 bit: il `ret` genera `#GP` e il kernel
   lascia **`$rip` sull'istruzione `ret` stessa**, non sul valore saltato
   — quindi `cyclic_find($rip)` fallirebbe. Verificato empiricamente che,
   in questo caso, il `#GP` lascia **`RSP` fermo sullo slot del return
   address** (non lo fa avanzare): l'offset si legge quindi da `*($rsp)`.
   (Su i386 il problema non si pone: ogni indirizzo a 32 bit è "canonico",
   il salto avviene e `$eip` contiene il pattern.)

4. **x86-64: allineamento dello stack per `system()`.** Come in
   `03-ret2libc`/`04-rop`, `system()` pretende `RSP` allineato a 16 byte.
   Nel ROP serviva un gadget `ret` di allineamento; qui, dato che la
   catena **non passa dallo stack**, è il gadget `g_exec` stesso ad
   allinearlo (`and $-16, %rsp`) prima della `call`.

5. **arm64: l'overflow colpisce il return address del CHIAMANTE, non di
   `vulnerable()`.** Su AArch64 gcc mette `buffer` in cima al frame di
   `vulnerable()` (`add x0, sp, #0x10`) e salva `x29/x30` **sotto** il
   buffer (`stp x29,x30,[sp,#-80]!`): scrivendo verso indirizzi crescenti,
   l'overflow **scavalca** il frame di `vulnerable()` (il cui `ret` verso
   `main` resta quindi intatto — infatti `main` stampa ancora `"Done."`)
   e corrompe il return address salvato da `main`. Inoltre, dopo quel
   `ret`, `SP` non punta allo slot del return address (come su x86) ma più
   in alto, di tutto il frame del chiamante. Per non fare ipotesi sulla
   dimensione dei frame, `exploit-arm64.py` misura **empiricamente in due
   fasi** (via gdb): (1) l'offset del return address corrotto con
   `cyclic_find($pc)`; (2) dove punta `SP` arrivati a `jop_start`, leggendo
   i byte ciclici lì e risalendo con `cyclic_find` all'offset del payload
   dove mettere la dispatch table.

6. **arm64: il payload deve essere esattamente lungo quanto `read()`.**
   `vulnerable()` fa `read(0, buffer, 300)`. Inizialmente l'exploit
   inviava un payload più lungo (400 byte): i ~100 byte in eccesso
   restavano nella pipe e, appena `system("/bin/sh")` apriva la shell,
   venivano letti **dalla shell** come suo primo comando
   (`/bin/sh: zaadbaad...: not found`) invece del nostro `id`. Bug
   insidioso perché *mascherato da gdb* (che non interagiva con la shell):
   sotto gdb `system` riceveva correttamente `x0 = &command = "/bin/sh"`,
   ma fuori falliva. Fix: payload di **esattamente 300 byte**, così la
   pipe resta pulita. (Le varianti x86 inviano payload più corti del
   buffer `read`, quindi il problema non si presenta lì.)

## arm64: portato — ed è il caso in cui AArch64 vince sul ROP

A differenza di `04-rop` — dove il porting ROP su AArch64 si scontra con un
**limite strutturale** (ogni salto "ret"-based lascia `LR` invariato e le
funzioni foglia entrano in self-loop, vedi `04-rop/README.md`, per cui
`04-rop` **non** è portato ad arm64) — qui il problema **non si presenta**:
la catena JOP non usa mai `ret`. Il dispatcher usa `br x1`
(branch-to-register), i gadget `b dispatcher`, e `g_exec` chiama `system`
con `bl` (che aggiorna `LR` legittimamente). `05-jop` è quindi l'esempio in
cui AArch64 si comporta **meglio** di x86 per i code-reuse a più stadi: la
stessa primitiva che blocca il ROP è irrilevante per il JOP.

Dettagli di implementazione (`#if defined(__aarch64__)` in `jop.c`): il
"PC" della catena è `X19` (callee-saved, non registro di argomento);
l'indirizzo di `command` si forma con `adrp`/`add :lo12:`; `g_bin`/`g_sh`
scrivono `"/bin"`/`"/sh\0"` con `movz`/`movk`+`str`. Nota collaterale:
dopo che la shell esce, `g_exec` fa `b dispatcher`, che prosegue oltre la
fine della tabella e termina con `SIGBUS` — innocuo (la shell è già stata
eseguita), esattamente come l'uscita anomala delle varianti x86.

## Stato

- **i386**: implementato e **verificato** (shell ottenuta). Offset 76.
- **x86-64**: implementato e **verificato** (shell ottenuta). Offset 72.
- **arm64**: implementato e **verificato** (shell ottenuta). Offset 72,
  dispatch table all'offset 80 del payload.

> Verificato: le varianti **i386/x86-64** su host x86-64 **nativo**
> (bruand81); la variante **arm64** su host arm64 **nativo** (Apple
> Silicon, immagine `vulnbox:arm64`). Tutte dentro container `vulnbox` di
> test, separati da quello usato in aula. Sotto QEMU su Apple Silicon
> valgono le note su ASLR/corefile già documentate per gli altri esempi.
