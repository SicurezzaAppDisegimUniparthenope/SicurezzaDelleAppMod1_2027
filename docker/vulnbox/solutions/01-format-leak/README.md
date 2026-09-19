# 01 — Format string: leak (`leak`)

Sorgente: `src/01-format-leak/leak.c` — binario compilato in `~student/bin/i386/leak`.
Legge l'input da **stdin** (non da `argv`, per poter includere in seguito
anche byte nulli negli altri esercizi — vedi nota in cima al sorgente):

```c
read(0, buf, sizeof(buf) - 1);
printf(buf);
```

`buf` diventa la *format string* di `printf`: se contiene `%x`/`%s`/`%p`
senza argomenti corrispondenti, `printf` continua a leggere valori dallo
stack (dove si trovano gli argomenti "mancanti").

## Dimostrazione in aula

1. Crash con troppi `%s` (printf prova a dereferenziare valori dello stack
   come se fossero puntatori a stringa — quasi sempre non validi):

   ```sh
   echo -n '%s%s%s%s%s%s%s%s' | leak
   ```

2. Dump dello stack in esadecimale, posizione per posizione:

   ```sh
   echo -n '%x.%x.%x.%x.%x.%x.%x.%x' | leak
   ```

3. Accesso diretto alla posizione N-esima nello stack (slide 14, `%n$x`):

   ```sh
   echo -n '%7$x' | leak
   ```

4. Leak di un indirizzo di memoria arbitrario: passare l'indirizzo come
   primi 4 byte dell'input e usare `%n$s` per farlo dereferenziare da
   `printf` come puntatore a stringa (qui con l'indirizzo di una stringa
   nel binario stesso, ricavabile con `gdb`/`objdump`, a scopo
   dimostrativo).

## Script (`exploit.py`)

Usa `pwntools` per individuare automaticamente, con un pattern crescente di
`%x`, a quale posizione dello stack si trova il primo argomento passato
(qui non c'è un segreto da rubare: lo script dimostra solo la tecnica,
stampando i primi N valori dello stack in esadecimale).

```sh
python3 exploit.py
```

## Variante amd64-64 bit (`exploit-x64.py`, `~student/bin/x64/leak`)

Stessa idea, con `%lx` (8 byte) al posto di `%x` (4 byte): su amd64 i
primi argomenti variadic di `printf` vengono letti dai registri
(RSI/RDX/RCX/R8/R9), non tutti dallo stack come su i386, ma il fenomeno
dimostrato è identico — printf continua a "consumare" argomenti
inesistenti (prima dai registri, poi dallo stack).

## Variante arm64 (`exploit-arm64.py`, `~student/bin/arm64/leak`)

Identica alla variante x64 (stesso `%lx`): la AAPCS64 legge i primi
argomenti variadic da X1-X7 (X0 è il puntatore al formato), poi dallo
stack — un registro in più rispetto ad amd64 prima di ricadere sullo
stack, nessun'altra differenza pratica.
