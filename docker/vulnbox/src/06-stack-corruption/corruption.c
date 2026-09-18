/*
 * Memory corruption - corruzione dell'indirizzo di ritorno.
 * Basato su "SS_2.1 - Memory Corruption.pptx", slide 18-29: una funzione
 * "ad alta sicurezza" mai invocata dal codice normale, raggiungibile solo
 * sovrascrivendo l'indirizzo di ritorno di lowSecurityFunction.
 *
 * Compilare con: vuln-gcc -o corruption corruption.c
 * Uso: input da stdin.
 */
#include <stdio.h>
#include <unistd.h>

void highSecurityFunction(void) {
    printf("TOP SECRET: non dovresti essere qui!\n");
}

void lowSecurityFunction(void) {
    char buffer[20];

    printf("Inserisci il tuo nome: ");
    fflush(stdout);

    read(0, buffer, 300);   /* nessun controllo sulla lunghezza rispetto a buffer[20]: overflow */
    printf("Ciao!\n");
}

int main(void) {
    lowSecurityFunction();
    return 0;
}
