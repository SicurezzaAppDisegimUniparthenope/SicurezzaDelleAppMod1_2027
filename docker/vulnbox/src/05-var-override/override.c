/*
 * Memory corruption - sovrascrittura di una variabile adiacente.
 * Basato su "SS_2.1 - Memory Corruption.pptx", slide 8-16: un buffer
 * troppo piccolo copiato senza controllo di lunghezza sovrascrive la
 * variabile allocata subito dopo di esso sullo stack.
 *
 * Compilare con: vuln-gcc -o override override.c
 * Uso: input da stdin.
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(void) {
    char buffer[12];
    int variable = 0;

    printf("Inserisci una stringa: ");
    fflush(stdout);

    ssize_t n = read(0, buffer, 300);   /* nessun controllo sulla lunghezza: overflow */
    if (n > 0 && buffer[n - 1] == '\n') {
        n--;
    }

    printf("buffer = %.*s\n", (int) (n > 0 ? n : 0), buffer);
    printf("variable = %d\n", variable);

    return 0;
}
