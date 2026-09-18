# 02 — Format string: data corruption (`write`)

Sorgente: `src/02-format-write/write.c` — binario compilato in
`~student/bin/write`. Obiettivo (slide 17-24): far diventare `flag != 0`
senza mai assegnarlo esplicitamente nel codice, solo tramite l'input.

## Procedura (manuale, per la lezione)

1. **Trovare l'indirizzo di `flag`** (variabile globale, quindi a indirizzo
   fisso: binario compilato `-no-pie`):

   ```sh
   objdump -t ~/bin/write | grep ' flag$'
   # oppure: nm ~/bin/write | grep ' flag$'
   ```

2. **Trovare a quale posizione nello stack (in termini di "parametro
   printf") finisce l'inizio del nostro input** — stesso principio della
   slide 20 ("padding per allineare"), ma verificato empiricamente invece
   che assunto: si manda un marchio riconoscibile seguito da `%N$x` e si
   aumenta `N` finché non si rivede il marchio nell'output.

   ```sh
   echo -n 'AAAA.%1$x' | write
   echo -n 'AAAA.%2$x' | write
   # ... finché non si legge 41414141 nell'output ⇒ quella è la posizione
   ```

3. **Scrivere all'indirizzo di `flag`** con `%n`: si mette l'indirizzo di
   `flag` in testa alla stringa (4 byte, little-endian) e si usa
   `%<N>$n` sulla posizione trovata al punto 2 (l'indirizzo stesso, essendo
   4 byte in testa alla stringa, occupa la prima posizione disponibile).

Il conteggio esatto dei byte stampati prima di `%n` determina *il valore*
scritto in `flag` (è il numero di caratteri emessi da `printf` fino a quel
punto) — per un valore preciso si usa il modificatore di larghezza, es.
`%123x` per forzare la stampa di 123 caratteri prima del `%n`.

## Script (`exploit.py`)

Automatizza i tre passi sopra con `pwntools` (`ELF` per l'indirizzo di
`flag`, ricerca automatica dell'offset, poi `fmtstr_payload` per costruire
il payload `%n` corretto):

```sh
python3 exploit.py
```
