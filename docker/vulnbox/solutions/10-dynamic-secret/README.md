# 10 — Dynamic analysis: segreto offuscato (`guessmyname2`)

Sorgente: `src/09-dynamic-secret/guessmyname2.c` — binario compilato in
`~student/bin/guessmyname2` **senza simboli di debug** (slide SS_1.3,
17-27): il nome non è più leggibile in chiaro con `readelf`/`strings`
(è offuscato con uno XOR), ma viene deoffuscato in una variabile in
chiaro a runtime.

> **Su host Apple Silicon**: i punti 2 e 3 (gdb live, `ltrace`) **non
> funzionano** in questo container — dipendono entrambi da `ptrace`, non
> supportato sotto l'emulazione QEMU necessaria su arm64 (vedi la nota
> in cima a `solutions/README.md`). Su un host x86_64 reale funzionano
> normalmente. In aula su Apple Silicon: dimostrare dal vivo solo il
> punto 1 (statico, funziona ovunque), e presentare i punti 2-3 con le
> slide/uno screen-recording preparato in anticipo su una macchina
> x86_64, oppure verificarli qui prima della lezione se si dispone di un
> host x86_64 su cui ricostruire il container.

## Dimostrazione in aula

1. **Verificare che `readelf`/`strings` non bastano più** (slide 18):

   ```sh
   readelf -x .rodata ~/bin/guessmyname2
   strings ~/bin/guessmyname2 | grep -i valeria   # niente
   ```

2. **`gdb` — analisi dinamica** (slide 19-24): breakpoint su `main`,
   esecuzione passo-passo con `nexti`, finché il nome deoffuscato non
   compare in un registro/nello stack:

   ```sh
   gdb ~/bin/guessmyname2
   (gdb) break main
   (gdb) run
   (gdb) nexti
   # ripetere nexti finché non si vede comparire la stringa in chiaro
   # (es. ispezionando i registri con 'info registers' o la memoria dopo
   # la chiamata a deobfuscate con 'x/s $eax' o l'indirizzo del buffer)
   ```

   Nota: essendo compilato senza `-g`, non si vedranno nomi di variabili
   o funzioni C (slide 20-22) — solo indirizzi e istruzioni assembly.

3. **`ltrace` — modo più rapido** (slide 27): intercetta le chiamate a
   funzioni di libreria, inclusa `strcmp(guess, secret)`, mostrando
   `secret` già deoffuscato come argomento:

   ```sh
   echo Valeria | ltrace ~/bin/guessmyname2
   ```

   Nell'output di `ltrace` compare la chiamata `strcmp("...", "Valeria")`
   con il secondo argomento già in chiaro, indipendentemente da cosa si è
   digitato come tentativo.

4. **Usare il nome trovato**:

   ```sh
   echo Valeria | guessmyname2
   ```
