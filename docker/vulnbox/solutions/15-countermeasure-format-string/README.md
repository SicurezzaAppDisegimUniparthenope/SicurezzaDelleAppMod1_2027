# 15 — Countermeasure: mitigazione format string (`vuln-format-off` / `vuln-format-on`)

Sorgente: `src/14-countermeasure-format-string/vuln.c` — stesso schema
dell'esempio 02 (corruzione di `flag` via `%n`), compilato due volte da
`build.sh`: `~student/bin/i386/vuln-format-off` (`printf(buf)`, vulnerabile) e
`~student/bin/i386/vuln-format-on` (`printf("%s", buf)`, sicuro) — slide
SS_2.2, 25 ("Mitigations").

## Dimostrazione in aula

1. **Stesso payload dell'esempio 02, contro entrambi i binari**:

   ```sh
   python3 exploit.py vuln-format-off   # riesce: flag corrotta
   python3 exploit.py vuln-format-on    # fallisce: il payload viene solo stampato
   ```

2. **Perché**: nella versione sicura l'input dell'utente è passato come
   **argomento** di `printf`, non come **format string**. `%n`, `%x`,
   `%7$x` ecc. vengono trattati come testo qualunque e stampati
   letteralmente — `printf` non li interpreta mai come specificatori,
   quindi non c'è alcun modo di leggere o scrivere memoria tramite
   l'input, indipendentemente da cosa contenga.

   La correzione è quindi minima e a costo prestazionale nullo: basta
   **non passare mai input non fidato come primo argomento (format
   string) di una funzione della famiglia `printf`**.

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/vuln-format-{off,on}`)

Stessa tecnica di `02-format-write` a 64 bit (vedi quel README):
`python3 exploit-x64.py vuln-format-off` / `vuln-format-on`.

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/vuln-format-{off,on}`)

Stessa tecnica di `02-format-write` in arm64 (vedi quel README):
`python3 exploit-arm64.py vuln-format-off` / `vuln-format-on`.
