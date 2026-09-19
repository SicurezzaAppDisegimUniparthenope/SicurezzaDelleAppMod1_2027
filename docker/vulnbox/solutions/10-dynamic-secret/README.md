# 10 — Dynamic analysis: segreto offuscato (`guessmyname2`)

Sorgente: `src/09-dynamic-secret/guessmyname2.c` — binario compilato in
`~student/bin/<arch>/guessmyname2` **senza simboli di debug** (slide SS_1.3,
17-27), dove `<arch>` è `i386`/`x64` sulla variante amd64 o `arm64` sulla
variante arm64: il nome non è più leggibile in chiaro con
`readelf`/`strings` (è offuscato con uno XOR), ma viene deoffuscato in una
variabile in chiaro a runtime.

> **Variante amd64 emulata (Apple Silicon senza `docker-compose.arm64.yml`)**:
> i punti 2 e 3 (gdb live, `ltrace`) **non funzionano** — dipendono
> entrambi da `ptrace`, non supportato sotto l'emulazione QEMU necessaria
> per amd64 su un host arm64 (vedi la nota in cima a `solutions/README.md`).
> Su un host x86_64 reale funzionano normalmente. In aula, con solo la
> variante amd64 disponibile su Apple Silicon: dimostrare dal vivo solo il
> punto 1 (statico, funziona ovunque), e presentare i punti 2-3 con le
> slide/uno screen-recording preparato in anticipo, oppure passare alla
> variante arm64 nativa (sotto).
>
> **Variante arm64 nativa**: verificato in questa sessione (host Apple
> M5) che i punti 1 e 2 funzionano **esattamente come su un host x86_64
> reale** (gdb live incluso — nessuna emulazione, quindi nessun limite
> ptrace). Il punto 3 (`ltrace`) resta però non disponibile per un motivo
> diverso: il pacchetto `ltrace` non esiste nei repository Debian bookworm
> per arm64 (non un limite di emulazione). `strace` funziona normalmente
> come alternativa parziale, ma non intercetta le chiamate di libreria
> come `strcmp` (solo syscall).

## Dimostrazione in aula

1. **Verificare che `readelf`/`strings` non bastano più** (slide 18):

   ```sh
   readelf -x .rodata ~/bin/<arch>/guessmyname2
   strings ~/bin/<arch>/guessmyname2 | grep -i valeria   # niente
   ```

2. **`gdb` — analisi dinamica** (slide 19-24): breakpoint su `main`,
   esecuzione passo-passo con `nexti`, finché il nome deoffuscato non
   compare in un registro/nello stack:

   ```sh
   gdb ~/bin/<arch>/guessmyname2
   (gdb) break main
   (gdb) run
   (gdb) nexti
   # ripetere nexti finché non si vede comparire la stringa in chiaro
   # (es. ispezionando i registri con 'info registers' o la memoria dopo
   # la chiamata a deobfuscate con 'x/s $eax' su i386/x64, o il registro
   # x0 su arm64, o l'indirizzo del buffer)
   ```

   Nota: essendo compilato senza `-g`, non si vedranno nomi di variabili
   o funzioni C (slide 20-22) — solo indirizzi e istruzioni assembly.

3. **`ltrace` — modo più rapido** (slide 27, solo variante amd64: pacchetto
   assente su arm64, vedi sopra): intercetta le chiamate a funzioni di
   libreria, inclusa `strcmp(guess, secret)`, mostrando `secret` già
   deoffuscato come argomento:

   ```sh
   echo Valeria | ltrace ~/bin/<arch>/guessmyname2
   ```

   Nell'output di `ltrace` compare la chiamata `strcmp("...", "Valeria")`
   con il secondo argomento già in chiaro, indipendentemente da cosa si è
   digitato come tentativo.

4. **Usare il nome trovato**:

   ```sh
   echo Valeria | ~/bin/<arch>/guessmyname2
   ```
