# 14 — Countermeasure: ASLR (`aslr`)

Sorgente: `src/13-countermeasure-aslr/aslr.c` — binario compilato in
`~student/bin/<arch>/aslr` (slide SS_2.4, 25-29, dove `<arch>` è `i386`/`x64`
sulla variante amd64 o `arm64` sulla variante arm64). Stampa l'indirizzo di
una variabile locale nello stack.

> **Variante amd64 emulata (Apple Silicon senza `docker-compose.arm64.yml`)**:
> l'indirizzo non cambia mai tra un'esecuzione e l'altra — limite
> dell'emulazione QEMU (l'ASLR del kernel guest non viene applicata ai
> processi emulati), non del container. `run-noaslr` fallisce comunque
> (`Function not implemented`), coerentemente. Su un host x86_64 reale
> funziona come descritto sotto.
>
> **Variante arm64 nativa**: verificato in questa sessione (host Apple
> M5) che l'ASLR randomizza realmente a ogni esecuzione, esattamente come
> su un host x86_64 reale (nessuna emulazione). `run-noaslr` inizialmente
> falliva anche qui, ma per un motivo diverso e non ovvio: non un limite
> del kernel, bensì il profilo seccomp di default del container runtime
> che blocca `personality(PER_LINUX|ADDR_NO_RANDOMIZE)` su questa
> architettura (`ENOSYS`, confermato con `strace`; `cap_add: SYS_PTRACE`
> da solo non basta). Fix già applicato in
> `docker-compose.arm64.yml` (`security_opt: [seccomp:unconfined]`): con
> l'immagine ricostruita a partire da questo fix, `run-noaslr` funziona
> normalmente.

## Dimostrazione in aula

1. **ASLR attivo (default del container)** — eseguire più volte,
   l'indirizzo cambia a ogni esecuzione (slide 29):

   ```sh
   for i in 1 2 3; do ~/bin/<arch>/aslr; done
   ```

2. **ASLR disattivato** (solo per il processo, via `personality`
   `ADDR_NO_RANDOMIZE` — non richiede privilegi né modifica
   `/proc/sys` a livello di container) — l'indirizzo resta identico
   a ogni esecuzione (slide 28):

   ```sh
   for i in 1 2 3; do run-noaslr ~/bin/<arch>/aslr; done
   ```

3. **Perché conta per gli esempi precedenti**: `ret2libc` (03), ROP (04)
   e shellcode injection (08) funzionano più facilmente/in modo
   deterministico proprio perché in questo container gli indirizzi del
   **binario stesso** sono sempre fissi (`-no-pie`); ASLR randomizza
   invece **stack/heap/librerie condivise** (slide 26) — è per questo
   che negli script di quegli esempi gli indirizzi di libc vengono letti
   dinamicamente dal processo appena lanciato invece di essere
   hardcoded.
