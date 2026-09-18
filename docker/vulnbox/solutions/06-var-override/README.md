# 06 — Memory corruption: sovrascrittura di variabile (`override`)

Sorgente: `src/05-var-override/override.c` — binario compilato in
`~student/bin/override` (slide SS_2.1, 8-16). `buffer[12]` e `variable`
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
