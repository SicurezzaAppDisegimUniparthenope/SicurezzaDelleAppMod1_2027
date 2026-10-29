# 08 — Memory corruption: shellcode injection (`shellcode`)

Sorgente: `src/08-shellcode/shellcode.c` — binario compilato in
`~student/bin/i386/shellcode` (slide SS_2.1, 35-46). `name[64]` viene riempito
con `read()` senza controllo di lunghezza, e lo stack è eseguibile
(`vuln-gcc` include `-z execstack`).

## Procedura (manuale, per la lezione)

1. **Verificare che l'overflow esista** (slide 37): mandare un pattern
   `cyclic` lungo e osservare il crash — con `dmesg`/`gdb` si può leggere
   `EIP` e convertirlo in offset con `cyclic_find()` (stessa tecnica degli
   esempi precedenti).

2. **Trovare un gadget `jmp *esp`** (slide 39): cerca la sequenza di byte
   `ff e4` (opcode di `jmp esp` su x86), prima nel binario poi in libc:

   ```sh
   objdump -d ~/bin/shellcode | grep 'jmp.*esp'
   objdump -d /usr/lib32/libc.so.6 | grep 'jmp.*esp'
   ```

   In **questo** container, con **questa** libc (build multilib, diversa
   dal pacchetto i386 nativo usato in altri esempi), nessuno dei due
   comandi trova nulla: non è un errore, è un'osservazione reale — un
   gadget del genere non è garantito esistere in un binario specifico,
   bisogna verificarlo caso per caso (la slide lo mostra su un binario
   dove esiste). Da manuale, il passo successivo sarebbe cercare un
   gadget equivalente altrove (altre librerie caricate, `call esp`,
   `push esp; ret`, ecc. — vedi `ropper --console` sul binario/libc).

3. **Alternativa usata da `exploit.py`, valida in questo container**:
   dato che qui l'ASLR non randomizza realmente lo stack (limite noto di
   QEMU user-mode su host arm64/Apple Silicon — vedi
   `solutions/14-countermeasure-aslr/README.md`), l'indirizzo dello
   stack è **stabile** tra un'esecuzione e l'altra. Il valore di `$esp`
   catturato nel corefile del crash usato per trovare l'offset (punto 1)
   corrisponde già, dopo il `ret` corrotto, all'indirizzo esatto dove
   finiranno i byte subito dopo il return address fasullo — cioè
   esattamente dove mettiamo lo shellcode. Si può quindi puntare il
   return address direttamente lì, **senza** alcun gadget. Su un host
   x86 nativo con ASLR realmente attiva questo non funzionerebbe: lì
   servirebbe un vero gadget `jmp esp` (risolto per ogni singolo run,
   dato che il resto del binario resta comunque a indirizzo fisso
   essendo `-no-pie`).

4. **Payload**: `padding(offset) + &shellcode + shellcode`. Lo shellcode
   si genera con `pwntools` (`shellcraft.i386.linux.sh()` + `asm(...)`),
   lo stesso approccio della slide 41-43.

## Script (`exploit.py`)

```sh
python3 exploit.py
```

Trova offset e indirizzo di destinazione automaticamente (dal corefile
del crash) e apre una shell interattiva.

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/shellcode`)

Stessa tecnica (nessun gadget `jmp rsp`/`call rsp` disponibile, verificato)
con una differenza importante rispetto a i386: qui **l'ASLR randomizza
davvero** stack/libc a ogni lancio (a differenza di i386, dove non
randomizza mai sotto QEMU). Si usa quindi `context.aslr = False` per
rendere l'indirizzo di stack letto dal corefile "usa e getta" valido
anche nel processo successivo — stesso compromesso adottato in
`03-ret2libc` (vedi quel README per il perché un vero leak non è
praticabile su questi binari). Shellcode generato con
`shellcraft.amd64.linux.sh()`.

## Variante host x86_64 nativo (`exploit-native.py`, `~student/bin/i386/shellcode`)

`exploit.py` (come `exploit-x64.py`) trova l'offset da `p.corefile`: funziona
**solo sotto QEMU user-mode**, dove è QEMU a scrivere un `core.<pid>` nella cwd
— proprio dove pwntools lo cerca. Su un **host x86_64 nativo** (es. `bruand81.it`,
vedi `docker/vulnbox/REMOTE.md`) i binari girano senza emulazione, quindi decide
il kernel dell'host: `core_pattern` è tipicamente una **pipe** (su Ubuntu
`|/usr/share/apport/apport …`), nessun file compare nella cwd e `p.corefile`
fallisce con *"Could not find core file"*. Non è aggirabile con `ulimit -c` né
cambiando `core_pattern` dal container (è del kernel host, non namespaced — stesso
muro della variante arm64).

`exploit-native.py` usa quindi lo stesso schema di `exploit-arm64.py`: **niente
corefile**, si allega `gdb` al processo già lanciato da pwntools e si leggono
`$eip`/`$esp`. Due accortezze specifiche:

- **`gdb -nx`**: il gdb del container ha GEF, il cui init è lento abbastanza da
  far crashare il processo *prima* che l'attach si completi (`Unable to attach:
  program terminated`). `-nx` salta i file di init e rende l'attach immediato.
- **`context.aslr = False`**: su host nativo l'ASLR randomizza davvero lo stack
  (sotto QEMU no — per questo `exploit.py` non ne aveva bisogno), quindi
  l'indirizzo "usa e getta" va reso stabile tra i due lanci (stessa scelta di
  `exploit-x64.py`/`exploit-arm64.py`).

Verificato su `bruand81.it`: `offset = 76` (coerente con `name[64]`), shell con
`uid=1000(student)`. Su host nativo con ASLR *realmente* attiva servirebbe invece
un vero gadget `jmp esp` risolto per ogni run (vedi i commenti di `exploit.py`).

La versione a 64 bit è `exploit-x64-native.py` (`~student/bin/x64/shellcode`),
con una finezza amd64 in più: un `ret` verso un indirizzo **non canonico** (gli
8 byte di cyclic) fa faultare la CPU sull'istruzione `ret` stessa, *prima* di
committare il pop. Due conseguenze, entrambe sfruttate: l'offset si legge da
`*(unsigned long *)$rsp` (il return address corrotto è ancora in cima allo stack),
e `$rsp` punta ancora **allo** slot del return address (non "subito dopo", come
col corefile QEMU dove la pop era già avvenuta), quindi lo shellcode — che nel
payload sta dopo il return address — si trova a `$rsp + 8`. Verificato su
`bruand81.it`: shell con `uid=1000(student)`.

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/shellcode`)

Stessa tecnica (`context.aslr = False`, nessun gadget `jmp/call sp`
disponibile), con una scoperta reale in più: l'indirizzo di stack va
letto **allegando gdb a un processo già lanciato da pwntools** (`gdb -p
PID`), non facendolo partire direttamente da gdb (`gdb --batch run <
payload BIN`) — le due modalità di lancio danno **indirizzi di stack
diversi** anche con ASLR disabilitata (ambiente/argv leggermente
diversi spostano il fondo dello stack di alcuni byte), scoperto per
tentativi in questa sessione dopo alcuni fallimenti intermittenti.
Niente corefile automatico (vedi `07-stack-corruption/README.md`).
Shellcode generato con `shellcraft.aarch64.linux.sh()`.
