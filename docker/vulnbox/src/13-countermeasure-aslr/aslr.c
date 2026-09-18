/*
 * Countermeasure: ASLR (Address Space Layout Randomization).
 * Basato su "SS_2.4 - Countermeasures.pptx", slide 27-29: un programma
 * che stampa l'indirizzo di una variabile locale (nello stack). Eseguito
 * più volte, l'indirizzo cambia se ASLR è attivo, resta costante se
 * disattivato (vedi run-noaslr).
 *
 * Compilare con: vuln-gcc -o aslr aslr.c
 */
#include <stdio.h>

int main(void) {
    int local_var = 42;
    printf("Indirizzo di local_var: %p\n", (void *) &local_var);
    return 0;
}
