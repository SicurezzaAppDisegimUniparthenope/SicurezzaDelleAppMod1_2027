# 12 — Countermeasure: NX (`vuln-nx-off` / `vuln-nx-on`)

Sorgente: `src/11-countermeasure-nx/vuln.c` — **stesso** sorgente dello
shellcode injection (esempio 08), compilato due volte da `build.sh`:
`~student/bin/vuln-nx-off` (stack eseguibile, come l'esempio 07/08) e
`~student/bin/vuln-nx-on` (stack non eseguibile) — slide SS_2.4, 6-11.

## Dimostrazione in aula

1. **Verificare la differenza con `readelf`** (slide 6-8): il segmento
   `GNU_STACK` mostra i permessi del futuro stack:

   ```sh
   readelf -l ~/bin/vuln-nx-off | grep -A1 GNU_STACK   # RWE
   readelf -l ~/bin/vuln-nx-on  | grep -A1 GNU_STACK   # RW
   ```

   O in modo equivalente con `pwntools` (slide 10):

   ```sh
   python3 -c "from pwn import *; print(ELF('/home/student/bin/vuln-nx-off').execstack)"
   python3 -c "from pwn import *; print(ELF('/home/student/bin/vuln-nx-on').execstack)"
   ```

2. **Stesso exploit dell'esempio 08 (shellcode injection), contro
   entrambi i binari**:

   ```sh
   python3 exploit.py vuln-nx-off   # riesce: shell (uid=...)
   python3 exploit.py vuln-nx-on    # fallisce: SIGSEGV invece della shell
   ```

   `exploit.py` punta l'indirizzo di ritorno direttamente sullo stack
   (nessun gadget `jmp esp`: vedi la nota in `solutions/08-shellcode/exploit.py`
   sul perché è possibile in questo container). Con NX attivo, il
   dirottamento del flusso avviene comunque, ma il tentativo di
   **eseguire** i byte dello shellcode nello stack genera un `SIGSEGV`
   invece di avviare la shell — esattamente la mitigazione descritta in
   slide 6 ("marking memory areas as non executable").

   Nota (slide 11): NX non protegge da un attacco return-to-libc/ROP
   (esempi 03/04), perché lì non si esegue codice iniettato nello stack,
   solo codice già presente ed eseguibile altrove (libc/binario stesso).
