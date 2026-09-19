# 06 — Memory corruption: sovrascrittura di variabile (`override`)

Sorgente: `src/05-var-override/override.c` — binario compilato in
`~student/bin/i386/override` (slide SS_2.1, 8-16). `buffer[12]` e `variable`
sono adiacenti sullo stack: un input più lungo di 12 byte trabocca su
`variable`.

## Dimostrazione in aula

1. Input corto (nessun effetto):

   ```sh
   echo -n 'ciao' | override
   ```

2. Input di 12+ byte: si osserva `variable` cambiare valore (slide 14):

   ```sh
   echo -n 'AAAAAAAAAAAABBBB' | override
   ```

   `variable` diventa l'intero corrispondente ai 4 byte `BBBB`
   (little-endian: `0x42424242` = 1111638594).

3. Script che calcola l'input per ottenere un valore scelto per
   `variable` (slide 15-16), analogo a `exploit.py`:

   ```sh
   python3 exploit.py
   ```

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/override`)

Identica: `variable` resta un `int` a 4 byte indipendentemente dalla
bitness del binario, quindi si passa esplicitamente `n=4` a
`cyclic()`/`cyclic_find()` invece di lasciare il default di pwntools (che
per `context.arch="amd64"` userebbe cicli a 8 byte, pensati per trovare
puntatori a 64 bit, non un `int`).

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/override`)

Identica alle altre due (`context.arch = "aarch64"`, `n=4`): funziona
invariata, nessuna sorpresa specifica di AArch64 per questo esempio
(l'overflow non tocca in alcun modo LR/x30).
