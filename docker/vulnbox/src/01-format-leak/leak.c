/*
 * Format string vulnerability - lettura (leak).
 * Basato su "SS_2.2 - Format-string vulnerabilities.pptx", slide 9-16:
 * un programma che si limita a fare "echo" dell'input passandolo
 * direttamente come format string a printf.
 *
 * Compilare con: vuln-gcc -o leak leak.c
 * Uso: echo -n '%x.%x.%x' | leak   (oppure lanciare 'leak' e scrivere
 * l'input a mano, terminando con invio)
 */
#include <stdio.h>
#include <unistd.h>

int main(void) {
    char buf[256];
    ssize_t n = read(0, buf, sizeof(buf) - 1);
    if (n <= 0) {
        return 1;
    }
    buf[n] = '\0';

    printf(buf);   /* vulnerabile: l'input dell'utente è la format string */
    printf("\n");

    return 0;
}
