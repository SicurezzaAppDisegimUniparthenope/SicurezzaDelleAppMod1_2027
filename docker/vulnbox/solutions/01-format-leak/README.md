# 01 — Format string: leak (`leak`)

Sorgente: `src/01-format-leak/leak.c` — binario compilato in `~student/bin/leak`.
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
