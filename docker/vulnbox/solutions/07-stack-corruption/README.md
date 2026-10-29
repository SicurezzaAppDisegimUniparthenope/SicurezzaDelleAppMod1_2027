# 07 — Memory corruption: corruzione del return address (`corruption`)

Sorgente: `src/07-stack-corruption/corruption.c` — binario compilato in
`~student/bin/i386/corruption` (slide SS_2.1, 18-29). `highSecurityFunction()`
non è mai chiamata dal codice normale: l'unico modo per raggiungerla è
sovrascrivere l'indirizzo di ritorno di `lowSecurityFunction()`.

## Procedura (manuale, per la lezione)

1. **Indirizzo di `highSecurityFunction`** (binario `-no-pie`, indirizzo
   fisso):

   ```sh
   objdump -t ~/bin/corruption | grep highSecurityFunction
   ```

2. **Offset fino al return address**: stesso procedimento di `ret2libc`
   (esempio 03) — pattern `cyclic`, crash, `cyclic_find()` su `EIP`.

3. **Payload**: `padding(offset) + &highSecurityFunction`.

## Script (`exploit.py`)

```sh
python3 exploit.py
```

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/corruption`)

Stessa tecnica, con l'indirizzo di ritorno a 8 byte (`p64` invece di
`p32`, `core.pc` invece di `core.eip`). Nota su `cyclic_find(..., n=8)`:
non è praticabile per un valore a 64 bit (va in hang — limite noto di
pwntools sulla ricerca de Bruijn con alfabeto a 8 byte); si usa il
default `n=4` sui primi 4 byte di RIP, sufficiente a un offset univoco
(pwntools stampa un warning informativo, atteso e innocuo).

## Variante host x86_64 nativo (`exploit-native.py`, `~student/bin/i386/corruption`)

`exploit.py` trova l'offset da `p.corefile`: funziona **solo sotto QEMU
user-mode**, dove è QEMU a scrivere un `core.<pid>` nella cwd. Su un **host
x86_64 nativo** (es. `bruand81.it`, vedi `docker/vulnbox/REMOTE.md`) i binari
girano senza emulazione: `core_pattern` è tipicamente una **pipe** (su Ubuntu
`|/usr/share/apport/apport …`), nessun file compare nella cwd e `p.corefile`
fallisce con *"Could not find core file"* (non aggirabile dal container:
core_pattern è del kernel host, non namespaced — stesso muro della variante
arm64).

`exploit-native.py` legge quindi `$eip` allegando `gdb` al processo già lanciato
da pwntools, come in `exploit-arm64.py`, con `gdb -nx` (il GEF del container ha
un init lento abbastanza da far crashare il processo prima che l'attach si
completi). A differenza di `08-shellcode` **non** serve `context.aslr = False`:
qui l'unico indirizzo usato (`highSecurityFunction`) viene dall'ELF `-no-pie` ed
è fisso, e l'offset è invariante rispetto all'ASLR. Verificato su `bruand81.it`:
`offset = 32` (coerente con `buffer[20]`), stampa "TOP SECRET".

La versione a 64 bit è `exploit-x64-native.py` (`~student/bin/x64/corruption`),
con una finezza amd64 in più: un `ret` verso un indirizzo **non canonico** (gli
8 byte di cyclic) fa faultare la CPU sull'istruzione `ret` stessa, *prima* di
committare il pop — quindi `$pc` resta sul `ret` e non contiene il pattern (sotto
QEMU il corefile invece lo conteneva). Il return address corrotto è però ancora
in cima allo stack, quindi l'offset si legge da `*(unsigned long *)$rsp` (troncato
a 4 byte da `cyclic_find`, come in `exploit-x64.py`: `n=8` va in hang). Verificato
su `bruand81.it`: stampa "TOP SECRET".

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/corruption`)

Concettualmente diversa da x86: niente "return address sullo stack",
il compilatore salva **LR (x30)** nel prologo di `lowSecurityFunction`
(`stp x29,x30,[sp,#N]`) e lo ricarica nell'epilogo (`ldp
x29,x30,[sp,#N]; ret` — `ret` salta all'indirizzo in x30). L'overflow
corrompe comunque quello slot, con lo stesso effetto pratico.

Due differenze reali di questo ambiente (arm64 gira nativo, non sotto
QEMU):

- **Niente corefile automatico**: su i386/x64 il corefile è generato da
  QEMU stesso al crash. Su arm64 nativo il crash passa dal vero
  meccanismo del kernel, il cui `core_pattern` punta a
  `systemd-coredump` (non disponibile/scrivibile in questo container,
  neanche con `sudo sysctl` — "permission denied"). Si usa quindi gdb in
  modalità batch per far crashare il programma sotto debugger e leggere
  `$pc` direttamente (gdb live funziona su arm64 nativo, a differenza di
  sotto QEMU).
- **`highSecurityFunction()` non è una funzione foglia** (chiama
  `printf`/`puts`): jumping into it via un "ret" corrotto (invece di una
  vera `bl`) fa sì che LR, all'ingresso, valga già l'indirizzo della
  funzione stessa — il suo stesso epilogo lo ripristina invariato dopo
  la chiamata interna, quindi il `ret` finale rientra sempre in se
  stessa: un **loop infinito** che ristampa "TOP SECRET" per sempre, non
  un crash come su x86. Innocuo per la dimostrazione (il messaggio viene
  comunque stampato), ma va letto con `recvuntil()` invece di
  `recvall()`, che altrimenti non termina mai.
