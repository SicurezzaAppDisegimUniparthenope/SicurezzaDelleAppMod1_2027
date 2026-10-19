/*
 * Static analysis - segreto hardcoded nel binario.
 * Basato su "SS_1.3 - Static and Dynamic Analysis.pptx", slide 10-14:
 * un programma che confronta l'input con una risposta "segreta" salvata
 * in chiaro come stringa costante (finisce in .rodata).
 *
 * Compilare con: vuln-gcc -o guessmyname guessmyname.c
 * Uso: input interattivo da stdin.
 */
#include <stdio.h>
#include <string.h>

static const char *secret_answer = "42";

int main(void) {
    char guess[64];

    printf("La risposta alla domanda fondamentale sulla vita, "
           "l'universo e tutto quanto è: ");
    fflush(stdout);

    if (!fgets(guess, sizeof(guess), stdin)) {
        return 1;
    }
    guess[strcspn(guess, "\n")] = '\0';

    if (strcmp(guess, secret_answer) == 0) {
        printf("Esatto! Complimenti.\n");
    } else {
        printf("Sbagliato, riprova.\n");
    }

    return 0;
}
