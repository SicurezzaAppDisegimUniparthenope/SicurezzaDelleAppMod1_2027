# 07 — Memory corruption: corruzione del return address (`corruption`)

Sorgente: `src/06-stack-corruption/corruption.c` — binario compilato in
`~student/bin/corruption` (slide SS_2.1, 18-29). `highSecurityFunction()`
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
