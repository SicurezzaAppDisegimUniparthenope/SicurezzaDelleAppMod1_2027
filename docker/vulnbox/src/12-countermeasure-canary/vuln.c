/*
 * Countermeasure: Stack Canary.
 * Basato su "SS_2.4 - Countermeasures.pptx", slide 12-19: stesso schema
 * di src/06-stack-corruption (highSecurityFunction raggiungibile solo
 * corrompendo l'indirizzo di ritorno), compilato due volte da build.sh
 * con e senza `-fstack-protector-all`, per confrontare dal vivo l'effetto
 * della protezione: con il canary, il programma termina con "*** stack
 * smashing detected ***" invece di eseguire highSecurityFunction.
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
