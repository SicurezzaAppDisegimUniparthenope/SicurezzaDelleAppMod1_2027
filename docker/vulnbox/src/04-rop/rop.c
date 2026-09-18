/*
 * Return Oriented Programming.
 * Basato su "SS_3.2 - Return Oriented Programming.pptx", slide 15-20:
 * stesso schema del tutorial citato in slide (http://www.codearcana.com),
 * una catena di chiamate add_bin() / add_sh() / exec_string() costruisce
 * la stringa "/bin/sh" ed esegue una shell, sfruttando il buffer overflow
 * in vulnerable() per incatenare le tre funzioni come "gadget".
 *
 * Compilare con: vuln-gcc -o rop rop.c
 * Uso: input (arbitrariamente lungo/binario, incluso il byte nullo di
 * terminazione della stringa costruita) da stdin.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

char command[32];

void add_bin(unsigned int value) {
    unsigned int *p = (unsigned int *) command;
    p[0] = value;
}

void add_sh(unsigned int value1, unsigned int value2) {
    unsigned int *p = (unsigned int *) (command + 4);
    p[0] = value1;
    p[1] = value2;
}

void exec_string(void) {
    system(command);
}

void vulnerable(void) {
    char buffer[64];
    read(0, buffer, 300);   /* nessun controllo sulla lunghezza rispetto a buffer[64]: overflow */
}

int main(void) {
    memset(command, 0, sizeof(command));
    vulnerable();
    printf("Done.\n");

    return 0;
}
