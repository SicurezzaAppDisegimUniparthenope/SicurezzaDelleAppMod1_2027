# 03 — Return-to-libc (`ret2libc`)

Sorgente: `src/03-ret2libc/ret2libc.c` — binario compilato in
`~student/bin/i386/ret2libc`. `vulnerable()` legge l'input da **stdin** in un
buffer di 64 byte con `read(0, buffer, 300)`, senza controllo di lunghezza
(slide SS_3.1).

## Procedura (manuale, per la lezione)

1. **Offset fino all'indirizzo di ritorno**: si manda un pattern
   riconoscibile (`pwntools cyclic(200)`), si lascia crashare il programma
   e si legge `EIP` al momento del crash, poi si usa `cyclic_find()` per
   convertirlo nell'offset esatto — niente numero fisso "hardcoded": la
   dimensione del frame dipende dal compilatore/allineamento.

   In questo container il debug **live** con gdb (`break`/`run`/`step`)
   non funziona (limite di `ptrace` sotto QEMU — vedi la nota in cima a
   `solutions/README.md`): si analizza invece **il core dump generato
   automaticamente da QEMU al crash**, che gdb può aprire senza bisogno
   di ptrace:

   ```sh
   python3 -c "
   import resource, subprocess
   resource.setrlimit(resource.RLIMIT_CORE, (resource.RLIM_INFINITY, resource.RLIM_INFINITY))
   from pwn import cyclic
   p = subprocess.Popen(['/home/student/bin/i386/ret2libc'], stdin=subprocess.PIPE)
   p.stdin.write(cyclic(200)); p.stdin.close(); p.wait()
   "
   ls qemu_ret2libc_*.core   # creato nella cwd da QEMU al SIGSEGV
   gdb -q -batch -ex 'print $eip' /home/student/bin/i386/ret2libc qemu_ret2libc_*.core
   python3 -c "from pwn import cyclic_find; print(cyclic_find(<valore di eip>))"
   ```

2. **Indirizzo di `system()` e della stringa `"/bin/sh"` in libc**: anche
   `run-noaslr` (basato su `setarch`/`personality`) non funziona sotto
   questa emulazione. Non serve comunque: si legge la mappatura di libc
   di un processo **in esecuzione** da `/proc/<pid>/maps` (una semplice
   lettura, non richiede ptrace), e l'offset di `system()`/`"/bin/sh"`
   dentro il file di libc con `objdump`/`strings` — esattamente il
   procedimento automatizzato da `exploit.py`:

   ```sh
   sleep 5 | /home/student/bin/i386/ret2libc &     # sleep tiene aperto lo stdin
   PID=$!
   grep 'libc\.so' /proc/$PID/maps | head -1        # base di libc caricata
   objdump -T /usr/lib32/libc.so.6 | grep ' system$' # offset di system() nel file
   # indirizzo runtime di system() = base + offset
   wait $PID 2>/dev/null
   ```

3. **Payload**: `padding(offset) + system() + exit() + "/bin/sh"` — dopo il
   `ret` corrotto, la funzione `vulnerable` "ritorna" dentro `system()` con
   `"/bin/sh"` come argomento; l'indirizzo dopo `system()` è l'indirizzo di
   ritorno di `system()` stesso (qui `exit()`, per uscire pulito invece di
   proseguire nel codice corrotto).

## Script (`exploit.py`)

```sh
python3 exploit.py
```

Determina l'offset con `cyclic`/corefile, ricava gli indirizzi di
`system`/`exit`/`"/bin/sh"` dalla libc effettivamente caricata a runtime
(`pwntools` legge `/proc/<pid>/maps` del processo), costruisce il payload e
apre una shell interattiva sul processo exploitato.

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/ret2libc`)

Stessa tecnica, con 3 differenze dovute alla ABI System V AMD64 (verificate
in sessione):
- il primo argomento di `system()` passa in **RDI**, non sullo stack:
  serve un gadget `pop rdi; ret`, che qui viene preso da libc (`ROP(libc)`)
  perché il binario stesso, minimale, non ne contiene uno.
- **`system()` richiede uno stack allineato a 16 byte** (glibc moderna,
  uso interno di istruzioni SSE): senza un `ret` di padding prima della
  chiamata, crasha subito dentro la libc, prima di eseguire `/bin/sh`.
- **l'ASLR qui randomizza davvero** stack/libc a ogni lancio (a differenza
  di i386, dove non randomizza mai sotto QEMU): lo script usa
  `context.aslr = False` per riusare lo schema "leak da un processo
  usa-e-getta poi lancio pulito" della variante i386, invece di un vero
  leak via ROP — verificato che il binario non contiene gadget sufficienti
  per un leak reale (niente `pop rdi/rsi/rdx`, niente il classico gadget
  universale `__libc_csu_init`, assente dalla glibc >= 2.34).

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/ret2libc`)

Stesso approccio (`context.aslr = False`, stessi motivi), ma con
differenze significative rispetto a x86:

- Argomenti in **x0-x7** (AAPCS64): `system("/bin/sh")` richiede x0 =
  indirizzo di `"/bin/sh"`.
- **Bug reale scoperto e corretto**: `pwntools.ROP()` (e `ROPgadget`
  standalone) **crashano** su QUALSIASI binario arm64 in questa immagine
  (`NameError: CS_ARCH_ARM64 is not defined`) — causato da una
  incompatibilità tra `ROPgadget==7.7` e la versione di `capstone`
  installata di default da pip (una **pre-release** `6.0.0a10`, non
  l'ultima stabile `5.0.9`, che ha rinominato `CS_ARCH_ARM64` in
  `CS_ARCH_AARCH64`). Fix: pin esplicito a `capstone==5.0.9` in
  [`Dockerfile`](../../Dockerfile).
- **Anche con il fix**, `ROP(libc).gadgets` trova solo gadget banali
  ("ret"/"ret;ret") in tutta la libc: il classificatore di gadget di
  pwntools per AArch64 non riconosce le sequenze `ldr`/`ldp`-da-stack
  come gadget "utilizzabili" (a differenza di x86, dove riconosce "pop
  reg"). Il gadget usato in questo script è stato cercato **a mano** via
  grep sul disassembly di libc (`objdump -d`): un pattern "epilogo con 2
  registri salvati" molto comune in AArch64 (`ldr x0, [sp,#120]; ldp
  x29,x30,[sp],#192; ret`), che permette di impostare x0 e saltare a un
  indirizzo scelto (x30) in un colpo solo — analogo concettuale del `pop
  rdi; ret` di x86. Il suo offset è quindi hardcoded nello script
  (potrebbe cambiare a un aggiornamento della libc).
- **Niente corefile automatico** su arm64 nativo (vedi
  `07-stack-corruption/README.md`): l'offset si trova con gdb in
  modalità batch invece che via `p.corefile`.
