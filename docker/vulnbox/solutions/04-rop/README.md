# 04 — Return Oriented Programming (`rop`)

Sorgente: `src/04-rop/rop.c` — binario compilato in `~student/bin/i386/rop`
(slide SS_3.2, esempio ripreso da codearcana.com citato in slide 15).

Il programma contiene tre funzioni pensate per essere incatenate come
"gadget" ad alto livello tramite l'overflow in `vulnerable()`:

- `add_bin(v)` — scrive 4 byte in `command[0..3]`
- `add_sh(v1, v2)` — scrive 8 byte in `command[4..11]`
- `exec_string()` — chiama `system(command)`

Costruendo `v = "/bin"` (little-endian) e `v1 = "/sh\0"`, la catena
`add_bin("/bin") → add_sh("/sh\0", 0) → exec_string()` fa eseguire
`system("/bin/sh")`.

## Procedura (manuale, per la lezione)

1. **Offset fino a EIP**: identico al caso `ret2libc` (stesso schema di
   `vulnerable()`), via `cyclic`/corefile.

2. **Indirizzi dei "gadget"**: qui non sono gadget assembly sparsi ma
   funzioni vere e proprie del binario — quindi il modo più semplice per
   trovarle è direttamente il simbolo, dato che il binario è compilato
   `-no-pie` (indirizzo fisso) e non stripped (`-g`):

   ```sh
   objdump -t ~/bin/rop | grep -E ' (add_bin|add_sh|exec_string)$'
   # oppure: nm ~/bin/rop | grep -E ' (add_bin|add_sh|exec_string)$'
   ```

3. **Convenzione cdecl e "pulizia" dello stack (slide 16-18)**: concatenare
   semplicemente `<&add_bin><&add_sh><arg>` **non** funziona, perché quando
   `add_bin` esegue il suo `ret`, ESP punta ancora allo slot dell'argomento
   di `add_bin` (nessuno lo ha "ripulito", a differenza di una `call`
   normale) — esattamente il problema descritto in slide 17. Serve un
   gadget `pop ; ret` (uno per l'argomento di `add_bin`, due — `pop; pop;
   ret` — per i due argomenti di `add_sh`) tra una chiamata e la
   successiva, per far avanzare ESP fino al prossimo indirizzo di
   funzione. Questi gadget si cercano nel binario con `ropper`/`ROPgadget`
   (slide 14), oppure si lasciano trovare automaticamente a `pwntools`
   (vedi `exploit.py`).

4. **Payload finale** (schema concettuale; `g1`/`g2` sono i gadget
   `pop;ret` / `pop;pop;ret` trovati al punto precedente):

   ```
   padding(offset)
   &add_bin       &g1            "/bin"
   &add_sh        &g2            "/sh\0"   0
   &exec_string
   ```

## Script (`exploit.py`)

```sh
python3 exploit.py
```

Ricava offset e indirizzi delle tre funzioni dal binario (via `ELF` di
`pwntools`, senza bisogno di ASLR off: il binario è `-no-pie`), costruisce
la catena ROP e apre una shell interattiva.

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/rop`)

Stessa catena `add_bin()`/`add_sh()`/`exec_string()`, con la differenza di
ABI System V AMD64: gli argomenti passano nei registri (RDI/RSI), quindi
servono gadget `pop rdi; ret`/`pop rsi; ret` (assenti nel binario stesso,
presi da libc con `ROP([elf, libc])`) al posto dei semplici `pop; ret`
cdecl. Come in `03-ret2libc`, `system()` (chiamata da `exec_string()`)
richiede uno stack allineato a 16 byte e `context.aslr = False` per lo
stesso motivo (nessun gadget per un leak reale, vedi la nota in
`03-ret2libc/README.md`).

## Variante arm64: NON portata (limite strutturale, documentato)

A differenza di `03-ret2libc` (dove si è trovato un gadget manuale
`ldr x0,[sp,#N]; ldp x29,x30,[sp],#M; ret` per chiamare `system()`),
concatenare **più funzioni in sequenza** (`add_bin()` → `add_sh()` →
`exec_string()`) su AArch64 si scontra con un limite strutturale della
ABI, non con un problema di tooling:

**Il problema**: qualunque salto "ret"-based su AArch64 (sia un overflow
diretto sul return address, sia un gadget che carica LR dallo stack)
lascia **X30 (LR) uguale all'indirizzo appena raggiunto** — è il valore
stesso appena usato per il salto, `ret` non lo modifica. Se la funzione
raggiunta è una **funzione foglia** (non chiama altro internamente, come
`add_bin`/`add_sh`: nessuna `bl` nel loro corpo — vedi anche la stessa
identica scoperta per `highSecurityFunction` in
`07-stack-corruption/README.md`, lì innocua perché serviva un solo
salto), il suo stesso `ret` finale userà quello stesso LR invariato,
**rientrando sempre in se stessa** — un loop infinito che riscrive solo
il PRIMO pezzo della stringa, senza mai proseguire alla funzione
successiva della catena.

Perché `03-ret2libc` invece funziona: lì si salta a `system()`, che
**non** è una funzione foglia (chiama internamente `fork`/`execve` con
vere istruzioni `bl`), quindi il suo LR viene legittimamente aggiornato
prima del suo `ret` finale — nessun self-loop.

**Come si risolverebbe in teoria**: servirebbe un gadget che usi `blr`
(branch-with-link **a registro**) invece di un semplice `ret` per
saltare da una funzione della catena alla successiva — un gadget che
aggiorni LR **legittimamente** ad ogni passaggio, analogo concettuale
della tecnica "ret2csu" di x86-64. Non è stato cercato/implementato in
questa sessione (richiede identificare un gadget `blr` utilizzabile nel
binario/libc, più complesso della ricerca già fatta per `03`): lasciato
come lavoro futuro se si vuole completare anche questo esempio per
arm64.
