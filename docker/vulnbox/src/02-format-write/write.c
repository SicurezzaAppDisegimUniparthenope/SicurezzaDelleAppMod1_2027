/*
 * Format string vulnerability - scrittura (data corruption).
 * Basato su "SS_2.2 - Format-string vulnerabilities.pptx", slide 17-24:
 * una variabile globale "flag" da corrompere tramite %n, sfruttando la
 * stessa printf(buf) vulnerabile dell'esempio di leak.
 *
 * Compilare con: vuln-gcc -o write write.c
 * Uso: input da stdin (vedi leak.c).
 */
#include <stdio.h>
#include <unistd.h>

int flag = 0;   /* obiettivo dell'esercizio: farla diventare != 0 */

void vulnerable(void) {
    char buf[256];
    ssize_t n = read(0, buf, sizeof(buf) - 1);
    if (n <= 0) {
        return;
    }
    buf[n] = '\0';

    printf(buf);  /* vulnerabile: l'input dell'utente è la format string */
    printf("\n");
}

int main(void) {
    vulnerable();

    if (flag != 0) {
        printf("Congratulazioni! flag = %d: hai corrotto la memoria.\n", flag);
    } else {
        printf("flag e' ancora 0.\n");
    }

    return 0;
}
