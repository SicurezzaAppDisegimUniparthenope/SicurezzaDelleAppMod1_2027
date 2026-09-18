# 08 — Memory corruption: shellcode injection (`shellcode`)

Sorgente: `src/07-shellcode/shellcode.c` — binario compilato in
`~student/bin/shellcode` (slide SS_2.1, 35-46). `name[64]` viene riempito
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
