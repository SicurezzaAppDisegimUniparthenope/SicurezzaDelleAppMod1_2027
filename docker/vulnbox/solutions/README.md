# Soluzioni — vulnbox

Materiale per il docente: per ognuno degli esempi in `src/` (montati già
compilati in `~student/bin/` dentro il container), la procedura per
sfruttare la vulnerabilità **su questa macchina** (indirizzi/offset non sono
universali: vanno ricavati sul binario effettivamente compilato dentro il
container, con gli strumenti indicati in ciascuna scheda).

Questa cartella è montata **solo** in `/home/vulnbox/solutions` (utente
docente, con sudo), non in `/home/student` — gli studenti non ci accedono
tramite il proprio account.

| # | Esempio | Slide di riferimento | Tecnica |
|---|---------|----------------------|---------|
| [01](01-format-leak/README.md) | `leak` | SS_2.2, slide 9-16 | Format string: lettura stack (`%x`, `%n$x`) |
| [02](02-format-write/README.md) | `write` | SS_2.2, slide 17-24 | Format string: scrittura arbitraria (`%n`) |
| [03](03-ret2libc/README.md) | `ret2libc` | SS_3.1 | Buffer overflow → return-to-libc (`system("/bin/sh")`) |
| [04](04-rop/README.md) | `rop` | SS_3.2 | Buffer overflow → ROP chain (`add_bin`/`add_sh`/`exec_string`) |
| [05](05-jop/README.md) | — | SS_3.3 | JOP: nota concettuale (nessun binario dedicato, vedi sotto) |
| [06](06-var-override/README.md) | `override` | SS_2.1, slide 8-16 | Memory corruption: sovrascrittura di variabile adiacente |
| [07](07-stack-corruption/README.md) | `corruption` | SS_2.1, slide 18-29 | Memory corruption: corruzione return address (funzione non autorizzata) |
| [08](08-shellcode/README.md) | `shellcode` | SS_2.1, slide 35-46 | Memory corruption: shellcode injection (`jmp *esp`) |
| [09](09-static-secret/README.md) | `guessmyname` | SS_1.3, slide 10-14 | Static analysis: segreto hardcoded (`readelf`/`strings`) |
| [10](10-dynamic-secret/README.md) | `guessmyname2` | SS_1.3, slide 17-27 | Dynamic analysis: segreto offuscato (`gdb`/`ltrace`) |
| [11](11-anti-debug/README.md) | `antidebug` | SS_1.3, slide 32-36 | Anti-debugging: self-debugging (`ptrace`) e bypass |
| [12](12-countermeasure-nx/README.md) | `vuln-nx-off`/`-on` | SS_2.4, slide 6-11 | Countermeasure: NX |
| [13](13-countermeasure-canary/README.md) | `vuln-canary-off`/`-on` | SS_2.4, slide 12-19 | Countermeasure: Stack Canary |
| [14](14-countermeasure-aslr/README.md) | `aslr` | SS_2.4, slide 25-29 | Countermeasure: ASLR |
| [15](15-countermeasure-format-string/README.md) | `vuln-format-off`/`-on` | SS_2.2, slide 25 | Countermeasure: mitigazione format string |

## Limiti noti su Apple Silicon (host arm64)

Verificato in questa sessione: sotto l'emulazione QEMU necessaria per far
girare binari x86 su un host arm64, `ptrace` **non funziona**
(`Function not implemented`) — il processo emulato non riesce a
tracciarne un altro. Questo rompe, **solo su questo tipo di host**:

- **gdb in modalità live** (`break`, `run`, `continue`, `nexti`, ecc.):
  non parte. Funziona però **gdb in modalità post-mortem**, cioè aperto
  su un core dump già generato (`gdb ./binario core-file`) — tecnica
  usata al posto del debug live dove serve (es. esempio 03).
- **`ltrace`/`strace`**: falliscono per lo stesso motivo.
- **`run-noaslr`** (`setarch`): fallisce (`Function not implemented`),
  coerentemente col fatto che l'ASLR non è comunque randomizzata in
  questo ambiente (vedi esempio 14) — non ne è comunque mai servito
  l'uso reale in nessuno script.
- **Esempio 11 (`antidebug`)**: `ptrace(PTRACE_TRACEME)` fallisce sempre
  anche senza alcun debugger collegato, quindi il programma segnala
  **sempre** "Debugger rilevato!" — l'esatto contrario dell'effetto
  dimostrativo voluto. Vedi la nota nel suo README.

Su un host x86_64 reale (dove tutto gira nativo, senza QEMU) nessuno di
questi problemi si presenta: `ptrace`, `gdb` live, `ltrace`/`strace` e
`run-noaslr` funzionano normalmente. Gli **script `exploit.py`** non
sono invece affetti da nessuno di questi limiti: usano tutti l'analisi
di core dump da file (un meccanismo diverso, non basato su ptrace) per
ricavare offset/indirizzi, motivo per cui funzionano in modo identico su
entrambi i tipi di host.

## Prerequisiti comuni

Tutti gli exploit sono script Python con `pwntools` (preinstallato nel
container) e vanno eseguiti **dentro** il container (hanno bisogno di
`gdb`/`objdump` sullo stesso binario a 32 bit, e per `ret2libc`/`rop` della
stessa libc caricata a runtime):

```sh
ssh -p 2201 vulnbox@localhost   # password: vulnbox
cd solutions/0N-.../
python3 exploit.py
```

Ogni `exploit.py` ricava dinamicamente offset/indirizzi (con `pwntools`
`cyclic`/`ELF`, o via `gdb`) invece di averli hardcoded: sono infatti diversi
a ogni build del container (allineamento dello stack, versione di libc,
ecc.), esattamente come accade agli studenti quando ripetono l'esercizio.
