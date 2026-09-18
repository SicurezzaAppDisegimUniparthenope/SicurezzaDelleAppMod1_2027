# 04 — Return Oriented Programming (`rop`)

Sorgente: `src/04-rop/rop.c` — binario compilato in `~student/bin/rop`
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
