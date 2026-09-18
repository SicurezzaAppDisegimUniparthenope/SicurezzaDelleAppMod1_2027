/*
 * Memory corruption - shellcode injection.
 * Basato su "SS_2.1 - Memory Corruption.pptx", slide 35-46: un buffer
 * overflow classico, sfruttato iniettando shellcode nello stack e
 * dirottando l'esecuzione su di esso tramite un gadget "jmp *esp"
 * presente nel binario stesso (indipendente da ASLR sullo stack, dato
 * che l'indirizzo di salto è relativo a %esp al momento del return, non
 * un indirizzo assoluto).
 *
 * Il buffer vulnerabile è in una funzione separata (non in main): main()
 * viene compilato da gcc con un epilogo diverso (riallineamento dinamico
 * dello stack via %ecx) che complica la sovrascrizione diretta
 * dell'indirizzo di ritorno.
 *
 * Compilare con: vuln-gcc -o shellcode shellcode.c
 * (richiede stack eseguibile: -z execstack, già incluso in vuln-gcc)
 * Uso: input da stdin.
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
