# 11 — Anti-debugging: self-debugging con `ptrace` (`antidebug`)

Sorgente: `src/10-anti-debug/antidebug.c` — binario compilato in
`~student/bin/antidebug` (slide SS_1.3, 32-36). Il programma chiama
`ptrace(PTRACE_TRACEME, ...)`: se un debugger lo sta già tracciando,
la chiamata fallisce e il programma esce subito.

> **Su host Apple Silicon**: **l'intero esempio non funziona come
> previsto** in questo container. `ptrace` non è supportato sotto
> l'emulazione QEMU necessaria su arm64 (vedi la nota in cima a
> `solutions/README.md`): la stessa chiamata `PTRACE_TRACEME` del
> programma fallisce **sempre**, quindi `antidebug` stampa **sempre**
> "Debugger rilevato!" anche senza alcun debugger — punto 1 incluso.
> Su un host x86_64 reale funziona esattamente come descritto sotto. Su
> Apple Silicon: presentare questo esempio solo a livello di codice
> sorgente/slide (spiegando il meccanismo), oppure verificarlo su un
> host x86_64 prima della lezione.

## Dimostrazione in aula (host x86_64 reale)

1. **Esecuzione normale** (nessun debugger, la traccia riesce):

   ```sh
   antidebug
   # "Nessun debugger rilevato, procedo normalmente."
   ```

2. **Sotto gdb** (`PTRACE_TRACEME` fallisce perché gdb sta già tracciando
   il processo — un processo può essere tracciato da un solo tracer alla
   volta):

   ```sh
   gdb ~/bin/antidebug
   (gdb) run
   # "Debugger rilevato! Uscita immediata."
   ```

3. **Bypass** (slide 36 — "find where ptrace is invoked, let the
   debugger skip it"): si mette un breakpoint sulla chiamata a `ptrace` e
   si forza il valore di ritorno a 0 (successo) prima che il codice lo
   controlli:

   ```sh
   gdb ~/bin/antidebug
   (gdb) break ptrace
   (gdb) run
   (gdb) return 0
   (gdb) continue
   # "Nessun debugger rilevato, procedo normalmente." anche sotto gdb!
   ```

   `return 0` di gdb forza la funzione corrente (`ptrace`) a restituire
   `0` senza eseguirla, esattamente il valore che il programma si aspetta
   in assenza di un debugger.
