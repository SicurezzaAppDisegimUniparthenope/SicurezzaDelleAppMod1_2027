# 14 — Countermeasure: ASLR (`aslr`)

Sorgente: `src/13-countermeasure-aslr/aslr.c` — binario compilato in
`~student/bin/aslr` (slide SS_2.4, 25-29). Stampa l'indirizzo di una
variabile locale nello stack.

## Dimostrazione in aula

1. **ASLR attivo (default del container)** — eseguire più volte,
   l'indirizzo cambia a ogni esecuzione (slide 29):

   ```sh
   for i in 1 2 3; do aslr; done
   ```

2. **ASLR disattivato** (solo per il processo, via `personality`
   `ADDR_NO_RANDOMIZE` — non richiede privilegi né modifica
   `/proc/sys` a livello di container) — l'indirizzo resta identico
   a ogni esecuzione (slide 28):

   ```sh
   for i in 1 2 3; do run-noaslr aslr; done
   ```

3. **Perché conta per gli esempi precedenti**: `ret2libc` (03), ROP (04)
   e shellcode injection (08) funzionano più facilmente/in modo
   deterministico proprio perché in questo container gli indirizzi del
   **binario stesso** sono sempre fissi (`-no-pie`); ASLR randomizza
   invece **stack/heap/librerie condivise** (slide 26) — è per questo
   che negli script di quegli esempi gli indirizzi di libc vengono letti
   dinamicamente dal processo appena lanciato invece di essere
   hardcoded.
