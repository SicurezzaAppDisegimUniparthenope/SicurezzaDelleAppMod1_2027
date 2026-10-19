# 09 — Static analysis: segreto hardcoded (`guessmyname`)

Sorgente: `src/09-static-secret/guessmyname.c` — binario compilato in
`~student/bin/<arch>/guessmyname` (slide SS_1.3, 10-14), dove `<arch>` è
`i386`/`x64` sulla variante amd64 o `arm64` sulla variante arm64 (vedi
tabella arch-per-esempio in cima a `solutions/README.md`). La risposta
segreta (`42`) è una stringa costante in chiaro, finisce nella sezione `.rodata`.

Verificato identico su tutte e 3 le combinazioni disponibili (i386, x64,
arm64): nessuna differenza di comportamento, essendo pura analisi statica.

## Dimostrazione in aula

1. **`readelf`**: leggere il contenuto di `.rodata`:

   ```sh
   readelf -x .rodata ~/bin/<arch>/guessmyname
   ```

   La risposta (`42`) è leggibile direttamente nell'esadecimale/ASCII a
   fianco, **subito prima** del testo della domanda (verificato su i386, x64
   e arm64).

2. **`strings`**: più rapido per un primo giro su binari più grandi.
   Attenzione: di default `strings` mostra solo sequenze di **almeno 4
   caratteri**, quindi `42` (2 caratteri) **non compare**:

   ```sh
   strings ~/bin/<arch>/guessmyname            # 42 assente
   strings -n 2 ~/bin/<arch>/guessmyname       # 42 presente (con più rumore)
   strings -n 2 ~/bin/<arch>/guessmyname | grep -B1 'La risposta'
   ```

   Spunto per l'aula: un segreto corto può sfuggire a un'analisi
   superficiale con le opzioni di default, ma non a chi sa cosa cercare —
   e il testo della domanda, che in `.rodata` segue subito la risposta, fa
   da "segnaposto" che porta dritti a lei.

3. **Usare la risposta trovata**:

   ```sh
   echo 42 | ~/bin/<arch>/guessmyname
   ```

**Morale (slide 12)**: non salvare mai segreti come stringhe costanti nel
binario.
