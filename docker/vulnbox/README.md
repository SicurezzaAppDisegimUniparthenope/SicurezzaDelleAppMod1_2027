# vulnbox

Container Debian per dimostrare agli studenti le vulnerabilità viste nelle
slide in `srcdocs/` (format string, return-to-libc, ROP, JOP, contromisure).
È volutamente separato dagli script QEMU in `scripts/` (che avviano le VM
ufficiali di Phoenix/Nebula): qui l'obiettivo non è riprodurre
exploit.education, ma avere un ambiente rapido, riavviabile e con una
cartella `src/` condivisa per lavorare in aula sul codice C delle slide.

## Varianti disponibili

Lo stesso sorgente C di ogni esempio viene compilato in **fino a 3
varianti**, scelte in fase di porting multi-arch (vedi
`TODO-multiarch.md`, gitignored):

| Variante | Bitness | Compose file | Porta SSH | Sottocartella binari |
|---|---|---|---|---|
| amd64 | 32 bit (`gcc -m32`, storica) | `docker-compose.yml` | 2201 | `~student/bin/i386/` |
| amd64 | 64 bit (`gcc -m64`, stessa immagine di sopra) | `docker-compose.yml` | 2201 | `~student/bin/x64/` |
| arm64 | 64 bit nativo (AArch64) | `docker-compose.arm64.yml` | 2202 | `~student/bin/arm64/` |

**Non esiste una variante arm64-32bit (armhf)**: verificato (Apple M5,
Podman/AppleHV) che gli host Apple Silicon non supportano l'esecuzione
AArch32 a EL0 nella VM Linux gestita da Docker/Podman (`Exec format
error` diretto dal kernel, nessun binfmt `qemu-arm` di fallback) — vedi
`TODO-multiarch.md` per l'evidenza completa. Le slide usano comunque
registri/syscall a 32 bit x86 (`int 0x80`), quindi la variante storica
i386 resta quella di riferimento per seguirle alla lettera; le varianti
a 64 bit (amd64 e arm64) sono un'estensione successiva per mostrare le
stesse tecniche con ABI moderne.

Le due immagini **amd64** e **arm64** possono girare in parallelo sullo
stesso host (porte SSH diverse) — utile per confrontare live lo stesso
esempio sulle due architetture.

## Quale variante scegliere / Apple Silicon

- **Host x86_64 reale** (Intel Mac, Windows, Linux x86_64): usare
  l'immagine **amd64** (`docker-compose.yml`), gira nativa senza
  emulazione — nessun limite, tutto funziona come descritto in questo
  README.
- **Host arm64** (Apple Silicon, Windows/Linux ARM64): **build/avvio
  automatici funzionano per entrambe le immagini** (Docker/Podman
  Desktop registrano da soli gli handler QEMU/binfmt per amd64), ma con
  differenze reali verificate in sessione:
  - L'immagine **amd64** gira **emulata** (QEMU user-mode) — più lenta,
    e con limiti noti: `ptrace` non funziona sotto l'emulazione, quindi
    **gdb live** (`break`/`run`/`step`) e **`ltrace`/`strace`** non
    funzionano (gdb in modalità **post-mortem**, su un core dump
    generato da QEMU al crash, sì). L'ASLR sulla parte **i386** non
    randomizza mai sotto questa emulazione (limite di QEMU, non del
    kernel); sulla parte **x64** invece randomizza normalmente. Gli
    script `exploit*.py` in `solutions/` non sono affetti da nessuno di
    questi limiti (analisi di core dump/gdb via `-p PID`, non ptrace
    diretto).
  - L'immagine **arm64** (`docker-compose.arm64.yml`) gira **nativa**
    (nessuna emulazione): **risolve tutti i limiti sopra** — `ptrace`,
    gdb live, `strace`, ASLR reale funzionano esattamente come su un
    host x86_64 reale. Unica eccezione residua: **`ltrace` non è
    disponibile** (pacchetto assente nei repository Debian bookworm per
    questa architettura, non un limite di emulazione). Per un'aula su
    Apple Silicon, questa è quindi la variante consigliata per le demo
    che richiedono debug live (dettagli completi, incluse 2 quirk reali
    di AArch64/gdb, in `solutions/README.md`).

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
oltre a `:latest` (amd64, variante storica) — più `:<release>-arm64` e
`:latest-arm64` per la variante arm64 nativa (il bare `:latest` resta
amd64: chi fa `docker pull` senza specificare piattaforma continua a
riceverla):

```sh
docker pull ghcr.io/sicurezzaappdisegimuniparthenope/vulnbox:latest-arm64
docker run -d --name vulnbox-arm64 -p 127.0.0.1:2202:22 --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    ghcr.io/sicurezzaappdisegimuniparthenope/vulnbox:latest-arm64
ssh -p 2202 student@localhost   # password: student (nessun sudo)
```

## Uso — docente (build locale, con `src/` e `solutions/` live)

```sh
cd docker/vulnbox
docker compose up -d --build                              # amd64 (i386/x64), porta 2201
docker compose -f docker-compose.arm64.yml up -d --build   # arm64, porta 2202 (solo su host arm64)
ssh -p 2201 student@localhost   # password: student (nessun sudo)
ssh -p 2201 vulnbox@localhost   # password: vulnbox (sudo NOPASSWD)
```

Nota: il wrapper `docker-compose`/Podman locale **ignora il campo
`platform:`** dei compose file in fase di build (bug verificato,
indipendente da questo progetto) — se il risultato non è quello atteso
(es. build amd64 anche lanciando il compose arm64 su host arm64), buildare
l'immagine direttamente con `podman build --platform linux/<arch> -t
vulnbox:<arch> .` e poi `docker compose -f docker-compose.<variante>.yml
up -d --no-build` per riusarla.

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
docker compose down                              # amd64
docker compose -f docker-compose.arm64.yml down  # arm64
```

## Difese disattivate

Il container **non** gira `--privileged`: si abbassano solo le difese sul
singolo binario/processo di volta in volta, così gli studenti vedono anche
il comportamento "protetto" cambiando i flag. Eccezione: **entrambe** le
immagini (`docker-compose.yml` e `docker-compose.arm64.yml`) usano
`seccomp:unconfined` — verificato in sessione che senza, il profilo
seccomp di default blocca `personality(ADDR_NO_RANDOMIZE)`
(`run-noaslr`) con `ENOSYS`, indipendentemente dall'architettura (non un
limite di emulazione QEMU come si pensava inizialmente — vedi
`solutions/14-countermeasure-aslr/README.md`); coerente comunque con lo
scopo del container, già deliberatamente vulnerabile.

- **Stack canary / NX / PIE**: compilare con il wrapper `vuln-gcc` al posto
  di `gcc` (equivalente a `gcc -fno-stack-protector -z execstack -no-pie`):

  ```sh
  vuln-gcc -o vulnerabile vulnerabile.c
  ```

- **ASLR**: disattivabile per singola esecuzione (senza toccare
  `/proc/sys` a livello di container) con `run-noaslr`, su entrambe le
  immagini (fix seccomp sopra):

  ```sh
  run-noaslr ./vulnerabile
  ```

  Sulla variante **amd64 emulata** su Apple Silicon l'ASLR sulla parte
  **i386** non randomizza comunque mai (limite di QEMU, non del kernel:
  `run-noaslr` "funziona" ma è ridondante lì); sulla parte **x64** e
  sulla variante **arm64 nativa** l'ASLR è reale (vedi
  `solutions/14-countermeasure-aslr/README.md`).

- **Verifica protezioni**: `pwntools` è preinstallato, quindi si può usare
  `pwn checksec ./vulnerabile` per controllare canary/NX/PIE/RELRO sul
  binario compilato.

- **gdb**: incluso [PEDA](https://github.com/longld/peda) (già configurato
  in `~/.gdbinit` per entrambi gli utenti) per ispezionare stack/registri
  durante il debug degli esempi ROP/JOP. Funziona sia live che
  post-mortem su host x86_64 reale e sulla variante **arm64 nativa**;
  **solo post-mortem** sulla variante amd64 emulata su Apple Silicon
  (vedi sopra).

- **Tool exploit dev**: `pwntools`, `ropper`/`ROPgadget` (ricerca gadget
  per ROP/JOP — su arm64, `pwntools.ROP()` richiede il fix
  `capstone==5.0.9` già applicato in questo `Dockerfile`, altrimenti
  crasha su qualunque binario arm64: bug reale di una pre-release di
  `capstone` installata di default da pip, vedi
  `solutions/03-ret2libc/README.md`), `objdump`, `strace` (su host
  x86_64 reale e sulla variante arm64 nativa; non sotto emulazione
  QEMU), `ltrace` (solo amd64: pacchetto assente nei repository Debian
  bookworm per arm64).

## Note di sicurezza

- SSH è pubblicato solo su `127.0.0.1` (non raggiungibile da altre macchine
  in rete): va bene per uso locale del docente/laboratorio, non per esporre
  il container su Internet.
- Credenziali (`student`/`student`, `vulnbox`/`vulnbox` con sudo senza
  password) sono deliberatamente deboli: pensate per un ambiente didattico
  locale, isolato, non per essere esposte.
