# Sicurezza delle Applicazioni Modulo 1 — Phoenix & Nebula via QEMU

Script per avviare in locale le VM didattiche di [exploit.education](https://exploit.education)
(**Phoenix** e **Nebula**) tramite QEMU, senza dover installare manualmente
VirtualBox/VMware. Ogni script installa QEMU se manca, scarica l'immagine
ufficiale e avvia la VM con il forwarding SSH già configurato.

Compatibili con **macOS (Intel e Apple Silicon)**, **Linux** (distro apt,
dnf/yum, pacman, zypper) e **Windows**.

## Struttura

```
scripts/
  phoenix/
    run-phoenix.sh    # macOS + Linux
    run-phoenix.ps1   # Windows
  nebula/
    run-nebula.sh      # macOS + Linux
    run-nebula.ps1      # Windows
```

## Prerequisiti

- **macOS / Linux**: `bash`, `curl`, `tar`. Su macOS non serve installare
  Homebrew a mano: se assente, lo script lo installa automaticamente (script
  ufficiale da [brew.sh](https://brew.sh)) prima di usarlo per installare
  QEMU — verrà chiesta la password amministratore. Su Linux serve un package
  manager supportato (apt, dnf/yum, pacman, zypper) per l'installazione
  automatica di QEMU.
- **Windows**: PowerShell 5.1+ (incluso in Windows 10/11), `tar` (incluso di
  default da Windows 10 1803+). [winget](https://learn.microsoft.com/it-it/windows/package-manager/winget/)
  o [Chocolatey](https://chocolatey.org/) per l'installazione automatica di
  QEMU — se assenti, installa QEMU manualmente da
  [qemu.weilnetz.de/w64](https://qemu.weilnetz.de/w64/) e rilancia lo script.
- Circa **1–2 GB di spazio libero** per ciascuna VM scaricata (le immagini
  vengono salvate in `~/.exploit-education/` e riusate ai run successivi).

Gli script vanno eseguiti **individualmente da ogni studente sulla propria
macchina** — non richiedono clonare il repository con permessi speciali, solo
gli script stessi.

## Log

Ogni esecuzione degli script bash (macOS/Linux) scrive un log dettagliato
(tutto l'output a schermo più la traccia dei comandi eseguiti) in una
cartella `logs/` creata accanto allo script stesso
(`scripts/phoenix/logs/phoenix-AAAAMMGG-HHMMSS.log`,
`scripts/nebula/logs/nebula-AAAAMMGG-HHMMSS.log`). Utile per diagnosticare un
problema (es. da allegare quando si chiede supporto). I file `*.log` sono
esclusi dal repository via `.gitignore`.

## Phoenix

Livelli su buffer overflow, format string ed heap exploitation su un sistema
"old-style" senza mitigazioni moderne.

### macOS / Linux

```bash
chmod +x scripts/phoenix/run-phoenix.sh   # solo la prima volta
./scripts/phoenix/run-phoenix.sh
```

### Windows (PowerShell)

```powershell
.\scripts\phoenix\run-phoenix.ps1
```

> Se PowerShell blocca l'esecuzione: apri PowerShell come utente normale e
> lancia una volta `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`,
> oppure esegui lo script con
> `powershell -ExecutionPolicy Bypass -File .\scripts\phoenix\run-phoenix.ps1`.

### Accesso

In modalità `--headless` (default) il log di boot scorre direttamente nel
terminale: la VM è pronta quando compare il prompt di login, es.:

```
Phoenix - brought to you by https://exploit.education/phoenix/
phoenix-arm64 login:
```

A quel punto, da un altro terminale:

```bash
ssh -p 2222 user@127.0.0.1     # password: user
ssh -p 2222 root@127.0.0.1     # password: root
```

I livelli si trovano in `/opt/phoenix/<architettura>` (es. `/opt/phoenix/amd64`
o `/opt/phoenix/arm64` a seconda dell'immagine scaricata).

### Opzioni disponibili (identiche su bash e PowerShell)

| Opzione (bash) | Opzione (PowerShell) | Descrizione | Default |
|---|---|---|---|
| `--headless` | *(default)* | Nessuna finestra grafica, output su console | attivo |
| `--gui` | `-Gui` | Avvia con finestra grafica QEMU | — |
| `--port PORT` | `-Port PORT` | Porta locale per SSH | 2222 |
| `--mem SIZE` | `-Mem SIZE` | RAM della VM (es. `1024M`, `2G`) | 1024M |
| `--arch amd64\|arm64` | `-Arch amd64\|arm64` | Forza l'architettura immagine | auto-rilevata |

Esempio:

```bash
./scripts/phoenix/run-phoenix.sh --gui --port 2200 --mem 2G
```

Su **Apple Silicon** e **Linux arm64** l'immagine `arm64` viene scaricata ed
eseguita **nativamente** (accelerazione hardware via HVF/KVM): nessuna perdita
di prestazioni rispetto a una VM "vera".

## Nebula

20 livelli classici di privilege escalation locale su Linux. A differenza di
Phoenix, è distribuita **solo** come ISO x86 a 32 bit avviabile direttamente
(nessuna installazione richiesta) — viene quindi sempre eseguita in emulazione
x86 via QEMU (nativa/accelerata su host x86_64, via TCG — più lenta ma
funzionante — su host arm64 come Apple Silicon).

### macOS / Linux

```bash
chmod +x scripts/nebula/run-nebula.sh   # solo la prima volta
./scripts/nebula/run-nebula.sh
```

### Windows (PowerShell)

```powershell
.\scripts\nebula\run-nebula.ps1
```

### Accesso

Attendere il boot della VM (10–30 secondi circa), poi:

```bash
ssh -p 2223 level00@127.0.0.1   # password: level00, per iniziare dal livello 0
ssh -p 2223 nebula@127.0.0.1    # password: nebula, poi "sudo -s" (password: nebula) per root
```

### Opzioni disponibili

| Opzione (bash) | Opzione (PowerShell) | Descrizione | Default |
|---|---|---|---|
| `--headless` | *(default)* | Nessuna finestra grafica | attivo |
| `--gui` | `-Gui` | Avvia con finestra grafica QEMU | — |
| `--port PORT` | `-Port PORT` | Porta locale per SSH | 2223 |
| `--mem SIZE` | `-Mem SIZE` | RAM della VM | 512M |

### Nota sulla scheda di rete

exploit.education non pubblica un comando QEMU ufficiale per Nebula (a
differenza di Phoenix): lo script usa il modello di rete `rtl8139`, il più
comune nei walkthrough della community. Se dopo il boot la VM non ottiene un
indirizzo IP via DHCP (SSH non risponde), prova un modello alternativo:

```bash
# macOS/Linux
NIC_MODEL=e1000 ./scripts/nebula/run-nebula.sh
# in alternativa: pcnet
```

```powershell
# Windows
.\scripts\nebula\run-nebula.ps1 -NicModel e1000
```

## Uscire dalla VM (modalità headless)

In modalità `--headless`/default, la console seriale della VM è collegata al
terminale. Per terminare QEMU: premi `Ctrl-A` seguito da `X`. In alternativa,
lavora sempre via SSH in un altro terminale e chiudi quello con QEMU con
`Ctrl-C`.

> **Nebula: non usare `sudo shutdown -h now` (o `poweroff`/`halt`) dentro la
> VM per terminare la sessione.** Il kernel Linux i386 della ISO Nebula (del
> 2010) non invia a QEMU il segnale ACPI di spegnimento: il sistema operativo
> si ferma ma il processo QEMU resta acceso "a vuoto", inutilizzabile (SSH
> non risponde più e sulla console/nel log compaiono ripetuti
> `Slirp: Failed to send packet, ret: -1`). Per terminare la sessione usa
> sempre `Ctrl-C` nel terminale dello script (o `Ctrl-A` poi `X` come sopra).
> Se ti ritrovi già in questa situazione, individua e chiudi il processo
> rimasto appeso:
>
> ```bash
> pkill -f qemu-system-i386
> ```
>
> Su Phoenix questo problema non si presenta: l'immagine ufficiale ha un
> kernel moderno con supporto ACPI corretto, quindi `shutdown -h now` fa
> terminare QEMU regolarmente.

## Problemi comuni

- **Il download si interrompe**: rilanciare semplicemente lo script — i file
  parziali vengono scaricati con estensione `.part` e sostituiti solo a
  download completato, quindi un run interrotto non lascia file corrotti.
- **`ssh: connect to host 127.0.0.1 port XXXX: Connection refused`**: la VM
  non ha ancora finito il boot, attendere qualche secondo e riprovare.
- **Porta già in uso**: un'altra istanza è già in ascolto su quella porta —
  usa `--port`/`-Port` con un valore diverso, oppure chiudi l'istanza
  precedente.
- **Windows Defender / SmartScreen blocca lo script**: click destro sul file
  `.ps1` → Proprietà → "Sblocca", oppure usa il flag `-ExecutionPolicy Bypass`
  indicato sopra.
- **macOS, primo avvio senza Homebrew**: lo script installa Homebrew da solo
  ed è normale che l'installazione richieda un paio di minuti e la password
  dell'utente (necessaria a `sudo` per completare il setup). I run successivi
  non ripetono questo passaggio.
