# 13 — Countermeasure: Stack Canary (`vuln-canary-off` / `vuln-canary-on`)

Sorgente: `src/12-countermeasure-canary/vuln.c` — **stesso** sorgente
della corruzione del return address (esempio 07: `highSecurityFunction`
raggiungibile solo tramite overflow), compilato due volte da `build.sh`:
`~student/bin/i386/vuln-canary-off` e `~student/bin/i386/vuln-canary-on`
(`-fstack-protector-all`) — slide SS_2.4, 12-19.

## Dimostrazione in aula

1. **Verificare la differenza con `pwn checksec`**:

   ```sh
   pwn checksec ~/bin/vuln-canary-off   # Stack: No canary found
   pwn checksec ~/bin/vuln-canary-on    # Stack: Canary found
   ```

2. **Stesso exploit dell'esempio 07 (corruzione del return address),
   contro entrambi i binari**:

   ```sh
   python3 exploit.py vuln-canary-off   # riesce: TOP SECRET
   python3 exploit.py vuln-canary-on    # fallisce: "*** stack smashing detected ***"
   ```

   Con il canary attivo, l'overflow **avviene comunque** (il programma
   scrive comunque oltre `buffer[20]`), ma prima del `ret` la funzione
   controlla che il valore-canary tra `buffer` e l'indirizzo di ritorno
   non sia stato alterato: essendolo, il programma abortisce
   immediatamente invece di saltare a `highSecurityFunction` (slide 14).

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/vuln-canary-{off,on}`)

Stessa tecnica di `07-stack-corruption` a 64 bit (`p64`, `core.pc`, vedi
quel README): `python3 exploit-x64.py vuln-canary-off` / `vuln-canary-on`.

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/vuln-canary-{off,on}`)

Stessa tecnica di `07-stack-corruption` in arm64 (offset via gdb batch,
LR/x30, loop infinito innocuo su `vuln-canary-off` — vedi quel README):
`python3 exploit-arm64.py vuln-canary-off` / `vuln-canary-on`. Sul
binario con canary attivo il programma abortisce prima di raggiungere
`ret`, quindi lì non si presenta il loop (si legge con `recvall()` come
al solito).
