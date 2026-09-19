# 11 — Anti-debugging: self-debugging con `ptrace` (`antidebug`)

Sorgente: `src/10-anti-debug/antidebug.c` — binario compilato in
`~student/bin/<arch>/antidebug` (slide SS_1.3, 32-36, dove `<arch>` è
`i386`/`x64` sulla variante amd64 o `arm64` sulla variante arm64). Il programma chiama
`ptrace(PTRACE_TRACEME, ...)`: se un debugger lo sta già tracciando,
la chiamata fallisce e il programma esce subito.

> **Variante amd64 emulata (Apple Silicon senza `docker-compose.arm64.yml`)**:
> **l'intero esempio non funziona come previsto**. `ptrace` non è
> supportato sotto l'emulazione QEMU necessaria per amd64 su un host
> arm64 (vedi la nota in cima a `solutions/README.md`): la stessa
> chiamata `PTRACE_TRACEME` del programma fallisce **sempre**, quindi
> `antidebug` stampa **sempre** "Debugger rilevato!" anche senza alcun
> debugger — punto 1 incluso. Su un host x86_64 reale funziona
> esattamente come descritto sotto. Con solo la variante amd64
> disponibile su Apple Silicon: presentare questo esempio solo a livello
> di codice sorgente/slide, o passare alla variante arm64 nativa (sotto).
>
> **Variante arm64 nativa**: verificato in questa sessione (host Apple
> M5) che i 3 punti sotto funzionano **esattamente come su un host x86_64
> reale** (nessuna emulazione, quindi nessun limite ptrace) — **con
> un'unica differenza nel punto 3**: gdb su AArch64 richiede un cast
> esplicito sul valore di ritorno (`return (int)0`, non `return 0`),
> perché senza simboli di debug per `ptrace` non conosce la dimensione del
> tipo di ritorno e si rifiuta di procedere ("Return value type not
> available for selected stack frame"). Su i386/x64 `return 0` senza cast
> è sufficiente.

## Dimostrazione in aula

1. **Esecuzione normale** (nessun debugger, la traccia riesce):

   ```sh
   ~/bin/<arch>/antidebug
   # "Nessun debugger rilevato, procedo normalmente."
   ```

2. **Sotto gdb** (`PTRACE_TRACEME` fallisce perché gdb sta già tracciando
   il processo — un processo può essere tracciato da un solo tracer alla
   volta):

   ```sh
   gdb ~/bin/<arch>/antidebug
   (gdb) run
   # "Debugger rilevato! Uscita immediata."
   ```

3. **Bypass** (slide 36 — "find where ptrace is invoked, let the
   debugger skip it"): si mette un breakpoint sulla chiamata a `ptrace` e
   si forza il valore di ritorno a 0 (successo) prima che il codice lo
   controlli:

   ```sh
   gdb ~/bin/<arch>/antidebug
   (gdb) break ptrace
   (gdb) run
   (gdb) return 0        # su arm64: return (int)0 — vedi nota sopra
   (gdb) continue
   # "Nessun debugger rilevato, procedo normalmente." anche sotto gdb!
   ```

   `return 0` di gdb forza la funzione corrente (`ptrace`) a restituire
   `0` senza eseguirla, esattamente il valore che il programma si aspetta
   in assenza di un debugger.
