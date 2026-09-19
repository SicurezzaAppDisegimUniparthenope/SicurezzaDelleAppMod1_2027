# Soluzioni — vulnbox

Materiale per il docente: per ognuno degli esempi in `src/`, la procedura per
sfruttare la vulnerabilità **su questa macchina** (indirizzi/offset non sono
universali: vanno ricavati sul binario effettivamente compilato dentro il
container, con gli strumenti indicati in ciascuna scheda). Ogni binario è
compilato in **fino a 3 varianti** dentro `~student/bin/`: `i386/` e `x64/`
(entrambe prodotte dall'immagine amd64, `docker-compose.yml`) e `arm64/`
(prodotta dall'immagine arm64 nativa, `docker-compose.arm64.yml` — vedi
`README.md` principale per come scegliere). Ogni README di esempio ha una
sezione dedicata per le varianti amd64-64/arm64 dove esistono differenze
reali rispetto alla variante i386 di riferimento.

Questa cartella è montata **solo** in `/home/vulnbox/solutions` (utente
docente, con sudo), non in `/home/student` — gli studenti non ci accedono
tramite il proprio account.

| # | Esempio | Slide di riferimento | Tecnica | i386 | amd64-64 | arm64 |
|---|---------|----------------------|---------|:---:|:---:|:---:|
| [01](01-format-leak/README.md) | `leak` | SS_2.2, slide 9-16 | Format string: lettura stack (`%x`, `%n$x`) | ✅ | ✅ | ✅ |
| [02](02-format-write/README.md) | `write` | SS_2.2, slide 17-24 | Format string: scrittura arbitraria (`%n`) | ✅ | ✅ | ✅ |
| [03](03-ret2libc/README.md) | `ret2libc` | SS_3.1 | Buffer overflow → return-to-libc (`system("/bin/sh")`) | ✅ | ✅ | ✅ |
| [04](04-rop/README.md) | `rop` | SS_3.2 | Buffer overflow → ROP chain (`add_bin`/`add_sh`/`exec_string`) | ✅ | ✅ | ❌ (limite strutturale, vedi README) |
| [05](05-jop/README.md) | — | SS_3.3 | JOP: nota concettuale (nessun binario dedicato, vedi sotto) | — | — | — |
| [06](06-var-override/README.md) | `override` | SS_2.1, slide 8-16 | Memory corruption: sovrascrittura di variabile adiacente | ✅ | ✅ | ✅ |
| [07](07-stack-corruption/README.md) | `corruption` | SS_2.1, slide 18-29 | Memory corruption: corruzione return address (funzione non autorizzata) | ✅ | ✅ | ✅ |
| [08](08-shellcode/README.md) | `shellcode` | SS_2.1, slide 35-46 | Memory corruption: shellcode injection (`jmp *esp`) | ✅ | ✅ | ✅ |
| [09](09-static-secret/README.md) | `guessmyname` | SS_1.3, slide 10-14 | Static analysis: segreto hardcoded (`readelf`/`strings`) | ✅ | ✅ | ✅ |
| [10](10-dynamic-secret/README.md) | `guessmyname2` | SS_1.3, slide 17-27 | Dynamic analysis: segreto offuscato (`gdb`/`ltrace`) | ✅ | ✅ | ✅ (`ltrace` assente, vedi README) |
| [11](11-anti-debug/README.md) | `antidebug` | SS_1.3, slide 32-36 | Anti-debugging: self-debugging (`ptrace`) e bypass | ✅ | ✅ | ✅ |
| [12](12-countermeasure-nx/README.md) | `vuln-nx-off`/`-on` | SS_2.4, slide 6-11 | Countermeasure: NX | ✅ | ✅ | ✅ |
| [13](13-countermeasure-canary/README.md) | `vuln-canary-off`/`-on` | SS_2.4, slide 12-19 | Countermeasure: Stack Canary | ✅ | ✅ | ✅ |
| [14](14-countermeasure-aslr/README.md) | `aslr` | SS_2.4, slide 25-29 | Countermeasure: ASLR | ✅ | ✅ | ✅ |
| [15](15-countermeasure-format-string/README.md) | `vuln-format-off`/`-on` | SS_2.2, slide 25 | Countermeasure: mitigazione format string | ✅ | ✅ | ✅ |

Nessuna variante **arm64-32bit (armhf)**: non disponibile su host Apple
Silicon (verificato, vedi `README.md` principale) — non è quindi in
tabella, non essendoci nulla da eseguire in quella combinazione.

## Limiti noti sulla variante amd64 emulata (host arm64 senza la variante arm64)

Verificato in questa sessione: sotto l'emulazione QEMU necessaria per far
girare la variante **amd64** su un host arm64 (Apple Silicon, se non si usa
`docker-compose.arm64.yml`), `ptrace` **non funziona**
(`Function not implemented`) — il processo emulato non riesce a
tracciarne un altro. Questo rompe, **solo con la variante amd64 emulata**:

- **gdb in modalità live** (`break`, `run`, `continue`, `nexti`, ecc.):
  non parte. Funziona però **gdb in modalità post-mortem**, cioè aperto
  su un core dump già generato (`gdb ./binario core-file`) — tecnica
  usata al posto del debug live dove serve (es. esempio 03).
- **`ltrace`/`strace`**: falliscono per lo stesso motivo.
- **Esempio 11 (`antidebug`)**: `ptrace(PTRACE_TRACEME)` fallisce sempre
  anche senza alcun debugger collegato, quindi il programma segnala
  **sempre** "Debugger rilevato!" — l'esatto contrario dell'effetto
  dimostrativo voluto. Vedi la nota nel suo README.

Su un host x86_64 reale (dove la variante amd64 gira nativa, senza QEMU)
questi due problemi non si presentano: `ptrace`, `gdb` live e
`ltrace`/`strace` funzionano normalmente. Gli **script `exploit.py`** non
sono invece affetti da nessuno di questi limiti: usano tutti l'analisi di
core dump da file (un meccanismo diverso, non basato su ptrace) per
ricavare offset/indirizzi, motivo per cui funzionano in modo identico
indipendentemente dall'emulazione.

**Correzione rispetto a quanto documentato inizialmente** (scoperta
durante il porting degli exploit a 64 bit, P4): `run-noaslr` **non**
falliva per un limite dell'emulazione QEMU come si pensava — falliva per
lo stesso motivo scoperto poi su arm64 nativo (vedi sezione successiva):
il profilo seccomp di default blocca
`personality(PER_LINUX|ADDR_NO_RANDOMIZE)` **indipendentemente
dall'architettura o dall'emulazione** (verificato: lo stesso identico
errore si riproduce anche disabilitando l'emulazione, e si risolve con
`seccomp:unconfined` su entrambe le varianti). Fix applicato anche a
[`docker-compose.yml`](../docker-compose.yml) (amd64): `run-noaslr`
funziona ora anche sulla variante amd64 di questo host, emulata o meno.

## Variante arm64 nativa (`docker-compose.arm64.yml`) — risolve i limiti sopra

Verificato in questa sessione (sanity-check P3, host Apple M5): la variante
**arm64**, girando nativamente (nessuna emulazione QEMU), risolve tutti i
limiti della sezione precedente **tranne uno**:

- **gdb in modalità live** e i tre punti dell'esempio 11 (`antidebug`,
  incluso il bypass): funzionano esattamente come su un host x86_64 reale.
  Unica differenza: nel passo di bypass (`return 0` su una funzione senza
  simboli di debug), **gdb su AArch64 richiede un cast esplicito**
  (`return (int)0`, non `return 0`) — altrimenti si ferma con "Return
  value type not available for selected stack frame". Vedi la nota
  nel README dell'esempio 11.
- **ASLR** (esempio 14): randomizza realmente a ogni esecuzione, proprio
  come su un host x86_64 reale (a differenza della variante amd64 emulata,
  dove è sempre fissa).
- **`ltrace`**: **resta non disponibile**, ma per un motivo diverso —
  non è un limite dell'emulazione ma un pacchetto assente nei repository
  Debian bookworm per l'architettura arm64 (`apt-cache policy ltrace`
  senza candidati). `strace` funziona normalmente.
- **`run-noaslr`**: inizialmente falliva anche in nativo
  (`personality(PER_LINUX|ADDR_NO_RANDOMIZE) = -1 ENOSYS`) — non per un
  limite del kernel, ma perché il **profilo seccomp di default** del
  container runtime blocca quella combinazione di flag, a prescindere
  dall'architettura (`strace` sul comando conferma l'`ENOSYS` esattamente
  su quella syscall; disabilitare seccomp lo risolve — confermato che lo
  stesso fix serve anche sulla variante amd64, vedi sezione precedente).
  Fix applicato in [`docker-compose.arm64.yml`](../docker-compose.arm64.yml)
  (e in [`docker-compose.yml`](../docker-compose.yml) per amd64):
  `security_opt: [seccomp:unconfined]` (coerente con lo scopo del
  container, già deliberatamente vulnerabile).

## Variante amd64-64 bit (`exploit-x64.py`)

Gli esempi con uno script Python (tutti tranne 09-11 e 14, che sono
walkthrough manuali) hanno un secondo script `exploit-x64.py` accanto a
`exploit.py`, per la stessa architettura amd64 ma sul binario a 64 bit
(`~student/bin/x64/...` invece di `~student/bin/i386/...`). Dettagli e
scelte specifiche nel README di ogni esempio; in sintesi (scoperto/deciso
durante il porting, P4):

- Differenze di ABI "meccaniche" (System V AMD64: argomenti nei registri,
  puntatori a 8 byte) gestite in ogni script (`p64`, `%lx`, ecc.).
- `cyclic_find(valore_a_64_bit, n=8)` **non è praticabile** (va in hang,
  limite noto di pwntools sulla ricerca de Bruijn con alfabeto a 8 byte):
  si usa sempre il default `n=4` (basta a un offset univoco), che stampa
  un warning innocuo.
- **`system()` richiede uno stack allineato a 16 byte** su questa glibc
  (`03-ret2libc`, `04-rop`): serve un `ret` di padding prima della
  chiamata finale, altrimenti crash immediato dentro la libc.
- **`03-ret2libc`/`04-rop`/`08-shellcode`/`12`**: qui, a differenza di
  i386 (dove l'ASLR non randomizza mai sotto QEMU), **l'ASLR randomizza
  davvero** stack/libc a ogni lancio del processo. Un vero leak-poi-exploit
  a 2 stadi via ROP non è praticabile su questi binari minimali: nessun
  gadget `pop rdi/rsi/rdx`, nessun `__libc_csu_init` (rimosso dalle
  glibc >= 2.34, quella di Debian bookworm inclusa) — verificato con una
  scansione approfondita (`ROPgadget --depth 30`). Scelta fatta: questi
  4 script usano `context.aslr = False` (pwntools lancia il processo con
  `personality(ADDR_NO_RANDOMIZE)`), riusando lo schema semplice già
  verificato per i386, invece di un leak reale o di modificare i sorgenti
  `.c` condivisi tra le architetture.
- Tutti e 10 gli `exploit-x64.py` sono stati eseguiti ed è stata
  verificata la shell/l'esito atteso (compresi i casi on/off delle
  contromisure 12/13/15).

## Variante arm64 (`exploit-arm64.py`)

Stesso principio della sezione precedente: script `exploit-arm64.py`
accanto agli altri due, sul binario `~student/bin/arm64/...`. **9 esempi
su 10 portati e verificati** (`01`, `02`, `03`, `06`, `07`, `08`, `12`,
`13`, `15`); **`04-rop` non è stato portato** — limite strutturale della
ABI AArch64, non di tooling, documentato in dettaglio in
[`04-rop/README.md`](04-rop/README.md). Dettagli e scelte specifiche nel
README di ogni esempio; in sintesi (scoperto/deciso durante il porting,
P5):

- **Niente corefile automatico su arm64 nativo**: a differenza di
  i386/x64 (dove QEMU stesso genera un corefile al crash), su arm64
  nativo il crash passa dal vero meccanismo del kernel, il cui
  `core_pattern` punta a `systemd-coredump` (non disponibile/scrivibile
  in questo container, verificato: neanche `sudo sysctl` lo permette —
  "permission denied", limite reale del container, non aggirabile senza
  privilegi che il container non concede). Tutti gli script che
  necessitano dell'offset lo trovano invece con **gdb in modalità
  batch** (`gdb -q --batch -ex "run < payload" -ex "print/x $pc" BIN`),
  possibile perché **gdb live funziona nativamente su arm64** (a
  differenza di sotto QEMU, vedi P3).
- **`cyclic_find(valore_a_64_bit, n=8)` impraticabile** (stesso limite
  già visto su x64): si usa il default `n=4`.
- **`highSecurityFunction()` (07/13) causa un loop infinito, non un
  crash**: chiamando `printf`/`puts` non è una funzione foglia, ma
  jumping into it via un "ret" corrotto (invece di una vera `bl`) lascia
  comunque **LR (x30) uguale al proprio indirizzo** all'ingresso — il
  suo stesso epilogo lo ripristina invariato, quindi il suo `ret` finale
  rientra sempre in se stessa. "TOP SECRET" viene comunque stampato la
  prima volta: gli script usano `recvuntil()` invece di `recvall()`, che
  altrimenti non termina mai.
- **Bug reale scoperto e corretto**: `pwntools.ROP()`/`ROPgadget`
  standalone **crashano** su QUALSIASI binario arm64 in questa immagine
  (`NameError: CS_ARCH_ARM64 is not defined`) — la versione di
  `capstone` installata di default da pip era una **pre-release**
  (`6.0.0a10`, non l'ultima stabile `5.0.9`), che ha rinominato
  `CS_ARCH_ARM64` in `CS_ARCH_AARCH64`. Fix: pin esplicito a
  `capstone==5.0.9` in [`Dockerfile`](../Dockerfile) — non influenza le
  build amd64 (il codepath ARM64 di ROPgadget non viene mai eseguito
  lì). **Anche con il fix**, il classificatore di gadget di pwntools per
  AArch64 resta limitato (trova solo "ret"/"ret;ret" in tutta la libc,
  niente sequenze `ldr`/`ldp`-da-stack): il gadget usato in
  `03-ret2libc` è stato cercato **a mano** via grep sul disassembly.
- **`03-ret2libc`**: stesso `context.aslr = False` di x64 e stesso
  motivo (nessun gadget diretto per un leak reale in questi binari
  minimali), ma qui il gadget per impostare X0 prima di chiamare
  `system()` esiste ed è stato trovato manualmente (vedi
  `03-ret2libc/README.md`).
- **`08-shellcode`/`12`**: stesso `context.aslr = False`. Scoperto per
  tentativi (dopo alcuni fallimenti intermittenti): l'indirizzo di stack
  letto lanciando gdb come processo indipendente (`gdb --batch run <
  payload BIN`) **non coincide** con quello di un processo lanciato da
  pwntools (`process(BIN)`), anche con ASLR disabilitata — le due
  modalità di lancio impostano un ambiente/argv leggermente diverso, che
  sposta il fondo dello stack di alcuni byte. Fix: allegare gdb (`gdb -p
  PID`) a un processo **già lanciato da pwntools**, invece di farlo
  partire direttamente da gdb.
- **`04-rop` non portato**: concatenare più funzioni-gadget
  (`add_bin()`→`add_sh()`→`exec_string()`) tramite semplice
  "ret"-chaining non funziona su AArch64 per funzioni foglia (stesso
  fenomeno di `highSecurityFunction` sopra, ma qui blocca il progresso
  della catena invece di essere solo cosmetico): servirebbe un gadget
  basato su `blr` (branch-with-link a registro) per aggiornare LR
  legittimamente ad ogni passaggio, non cercato in questa sessione. Vedi
  `04-rop/README.md` per il dettaglio completo.

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
