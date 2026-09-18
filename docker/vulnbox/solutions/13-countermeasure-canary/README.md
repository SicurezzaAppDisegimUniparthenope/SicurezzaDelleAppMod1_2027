# 13 — Countermeasure: Stack Canary (`vuln-canary-off` / `vuln-canary-on`)

Sorgente: `src/12-countermeasure-canary/vuln.c` — **stesso** sorgente
della corruzione del return address (esempio 07: `highSecurityFunction`
raggiungibile solo tramite overflow), compilato due volte da `build.sh`:
`~student/bin/vuln-canary-off` e `~student/bin/vuln-canary-on`
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
