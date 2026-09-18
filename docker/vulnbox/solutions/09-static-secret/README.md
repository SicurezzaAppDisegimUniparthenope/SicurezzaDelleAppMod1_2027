# 09 — Static analysis: segreto hardcoded (`guessmyname`)

Sorgente: `src/08-static-secret/guessmyname.c` — binario compilato in
`~student/bin/guessmyname` (slide SS_1.3, 10-14). Il nome segreto è una
stringa costante in chiaro, finisce nella sezione `.rodata`.

## Dimostrazione in aula

1. **`readelf`**: leggere il contenuto di `.rodata`:

   ```sh
   readelf -x .rodata ~/bin/guessmyname
   ```

   Il nome (`Michele`) è leggibile direttamente nell'esadecimale/ASCII a
   fianco.

2. **`strings`**: più rapido per un primo giro su binari più grandi:

   ```sh
   strings ~/bin/guessmyname
   ```

3. **Usare il nome trovato**:

   ```sh
   echo Michele | guessmyname
   ```

**Morale (slide 12)**: non salvare mai segreti come stringhe costanti nel
binario.
