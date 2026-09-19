# 09 — Static analysis: segreto hardcoded (`guessmyname`)

Sorgente: `src/08-static-secret/guessmyname.c` — binario compilato in
`~student/bin/<arch>/guessmyname` (slide SS_1.3, 10-14), dove `<arch>` è
`i386`/`x64` sulla variante amd64 o `arm64` sulla variante arm64 (vedi
tabella arch-per-esempio in cima a `solutions/README.md`). Il nome segreto
è una stringa costante in chiaro, finisce nella sezione `.rodata`.

Verificato identico su tutte e 3 le combinazioni disponibili (i386, x64,
arm64): nessuna differenza di comportamento, essendo pura analisi statica.

## Dimostrazione in aula

1. **`readelf`**: leggere il contenuto di `.rodata`:

   ```sh
   readelf -x .rodata ~/bin/<arch>/guessmyname
   ```

   Il nome (`Michele`) è leggibile direttamente nell'esadecimale/ASCII a
   fianco.

2. **`strings`**: più rapido per un primo giro su binari più grandi:

   ```sh
   strings ~/bin/<arch>/guessmyname
   ```

3. **Usare il nome trovato**:

   ```sh
   echo Michele | ~/bin/<arch>/guessmyname
   ```

**Morale (slide 12)**: non salvare mai segreti come stringhe costanti nel
binario.
