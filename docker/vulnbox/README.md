# vulnbox

Container Debian **i386 (32-bit)** per dimostrare agli studenti le
vulnerabilità viste nelle slide in `srcdocs/` (format string,
return-to-libc, ROP, JOP). È volutamente separato dagli script QEMU in
`scripts/` (che avviano le VM ufficiali di Phoenix/Nebula): qui l'obiettivo
non è riprodurre exploit.education, ma avere un ambiente rapido, riavviabile
e con una cartella `src/` condivisa per lavorare in aula sul codice C delle
slide.

## Perché amd64 + `gcc -m32` e non un'immagine i386 nativa

Le slide usano registri a 32 bit (EAX/EBX/ECX/EDX) e syscall via `int 0x80`
(ABI a 32 bit): gli esempi vanno quindi compilati ed eseguiti a 32 bit
(`vuln-gcc` include `-m32`). L'immagine di base però è **amd64**
(`debian:bookworm-slim` + `gcc-multilib`/`g++-multilib`), non
`i386/debian`: su un host x86_64 reale (Intel Mac, Windows, Linux
x86_64) questo fa girare tutto **nativamente**, kernel IA32-compat
incluso — nessuna emulazione, ASLR realmente randomizzata, `ptrace`
(quindi `gdb` live, `ltrace`/`strace`) pienamente funzionante.

## Apple Silicon

Docker/Podman Desktop su macOS registrano automaticamente gli handler
QEMU/binfmt per le architetture non native: build e avvio funzionano senza
configurazione aggiuntiva, ma **più lentamente** del normale (ogni
istruzione emulata, nessuna accelerazione hardware) — per demo in aula con
binari piccoli va comunque bene. **Limiti noti solo su questo tipo di
host** (verificati in sessione, dettagli e alternative funzionanti in
`solutions/README.md`): `ptrace` non è supportato sotto l'emulazione, quindi
**gdb live** (`break`/`run`/`step`), **`ltrace`/`strace`** e
**`run-noaslr`** non funzionano — gdb in modalità **post-mortem** (su un
core dump già generato) invece sì. Gli script `exploit.py` in
`solutions/` non sono affetti (usano l'analisi di core dump, non ptrace)
e funzionano identici su entrambi i tipi di host.

## Uso — studenti (immagine già pubblicata, consigliato)

Non serve clonare il repo né buildare nulla: l'immagine su GitHub Container
Registry contiene già gli esempi compilati al primo avvio.

```sh
docker pull ghcr.io/sicurezzaappdisegimuniparthenope/vulnbox:latest
docker run -d --name vulnbox -p 127.0.0.1:2201:22 --cap-add=SYS_PTRACE \
    ghcr.io/sicurezzaappdisegimuniparthenope/vulnbox:latest
ssh -p 2201 student@localhost   # password: student (nessun sudo)
```

L'immagine viene ripubblicata a ogni release del repository (vedi
`.github/workflows/vulnbox-image.yml`), tag nel formato `YYYYMMDDHHMM`
oltre a `:latest`.

## Uso — docente (build locale, con `src/` e `solutions/` live)

```sh
cd docker/vulnbox
docker compose up -d --build
ssh -p 2201 student@localhost   # password: student (nessun sudo)
ssh -p 2201 vulnbox@localhost   # password: vulnbox (sudo NOPASSWD)
```

Due account distinti:

- **`student`**: senza sudo, è l'account con cui si eseguono gli esempi
  vulnerabili (stessi permessi di un utente non privilegiato sul sistema
  target — coerente con gli esercizi di privilege escalation).
- **`vulnbox`**: con sudo senza password, per il docente/setup
  (installare pacchetti aggiuntivi, ispezionare il sistema, ecc.).

La cartella `docker/vulnbox/src/` sull'host è condivisa in
`/home/student/src` nel container: mettici i sorgenti C degli esempi da
seguire con gli studenti.

Per fermare/rimuovere il container:

```sh
docker compose down
```

## Difese disattivate

Il container **non** disattiva le protezioni a livello di sistema (niente
`--privileged`, niente `seccomp:unconfined`): si abbassano solo le difese sul
singolo binario/processo di volta in volta, così gli studenti vedono anche
il comportamento "protetto" cambiando i flag.

- **Stack canary / NX / PIE**: compilare con il wrapper `vuln-gcc` al posto
  di `gcc` (equivalente a `gcc -fno-stack-protector -z execstack -no-pie`):

  ```sh
  vuln-gcc -o vulnerabile vulnerabile.c
  ```

- **ASLR**: disattivabile per singola esecuzione (senza toccare
  `/proc/sys` a livello di container) con `run-noaslr` — su host x86_64
  reale. **Su Apple Silicon `run-noaslr` non funziona** (`setarch`
  fallisce sotto l'emulazione), ma non ne serve comunque l'uso: in
  quell'ambiente l'ASLR non randomizza comunque nulla (vedi
  `solutions/14-countermeasure-aslr/README.md`):

  ```sh
  run-noaslr ./vulnerabile
  ```

- **Verifica protezioni**: `pwntools` è preinstallato, quindi si può usare
  `pwn checksec ./vulnerabile` per controllare canary/NX/PIE/RELRO sul
  binario compilato.

- **gdb**: incluso [PEDA](https://github.com/longld/peda) (già configurato
  in `~/.gdbinit` per entrambi gli utenti) per ispezionare stack/registri
  durante il debug degli esempi ROP/JOP. Su host x86_64 reale funziona sia
  live che post-mortem; **su Apple Silicon solo post-mortem** (vedi sopra).

- **Tool exploit dev**: `pwntools`, `ropper` (ricerca gadget per ROP/JOP),
  `objdump`, `strace`/`ltrace` (questi ultimi due: solo su host x86_64
  reale, non su Apple Silicon — vedi sopra).

## Note di sicurezza

- SSH è pubblicato solo su `127.0.0.1` (non raggiungibile da altre macchine
  in rete): va bene per uso locale del docente/laboratorio, non per esporre
  il container su Internet.
- Credenziali (`student`/`student`, `vulnbox`/`vulnbox` con sudo senza
  password) sono deliberatamente deboli: pensate per un ambiente didattico
  locale, isolato, non per essere esposte.
