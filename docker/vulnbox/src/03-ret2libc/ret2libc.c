/*
 * Return-to-libc.
 * Basato su "SS_3.1 - Return-to-libc.pptx": buffer overflow classico su
 * stack, sfruttato per far chiamare system("/bin/sh") senza bisogno di
 * uno stack eseguibile.
 *
 * Compilare con: vuln-gcc -o ret2libc ret2libc.c
 * Uso: input (arbitrariamente lungo/binario) da stdin.
 */
#include <stdio.h>
#include <unistd.h>

void vulnerable(void) {
    char buffer[64];
    ssize_t n = read(0, buffer, 300);   /* nessun controllo sulla lunghezza rispetto a buffer[64]: overflow */
    printf("You said: %.*s\n", (int) (n > 0 ? n : 0), buffer);
}

int main(void) {
    vulnerable();
    printf("Done.\n");

    return 0;
}
