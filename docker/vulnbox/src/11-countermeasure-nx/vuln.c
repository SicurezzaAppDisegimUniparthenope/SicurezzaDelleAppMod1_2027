/*
 * Countermeasure: NX (stack non eseguibile).
 * Basato su "SS_2.4 - Countermeasures.pptx", slide 6-11: stesso schema di
 * shellcode injection (src/07-shellcode), compilato due volte da build.sh
 * con NX disattivato (esattamente come lo shellcode.c originale) e con NX
 * attivato, per confrontare dal vivo l'effetto della protezione: lo
 * shellcode iniettato nello stack non può più essere eseguito (SIGSEGV
 * invece di una shell).
 *
 * Buffer vulnerabile in una funzione separata (non in main), vedi nota
 * in src/07-shellcode/shellcode.c.
 */
#include <stdio.h>
#include <unistd.h>

void vulnerable(void) {
    char name[64];

    printf("Come ti chiami? ");
    fflush(stdout);

    read(0, name, 300);   /* nessun controllo sulla lunghezza rispetto a name[64]: overflow */
    printf("Ciao %s, piacere di conoscerti!\n", name);
}

int main(void) {
    vulnerable();
    return 0;
}
