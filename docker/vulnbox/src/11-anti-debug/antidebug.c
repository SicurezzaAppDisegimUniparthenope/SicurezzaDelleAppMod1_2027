/*
 * Anti-debugging - self-debugging con ptrace.
 * Basato su "SS_1.3 - Static and Dynamic Analysis.pptx", slide 32-36: il
 * programma prova a tracciare se stesso con PTRACE_TRACEME; se fallisce
 * (perché un debugger lo sta già tracciando) si considera "sotto
 * osservazione" e termina.
 *
 * Compilare con: vuln-gcc -o antidebug antidebug.c
 * Richiede la capability SYS_PTRACE (già presente nel container).
 */
#include <stdio.h>
#include <stdlib.h>
#include <sys/ptrace.h>
#include <unistd.h>

int main(void) {
    if (ptrace(PTRACE_TRACEME, 0, NULL, NULL) < 0) {
        printf("Debugger rilevato! Uscita immediata.\n");
        exit(1);
    }

    printf("Nessun debugger rilevato, procedo normalmente.\n");
    printf("Operazione segreta eseguita con successo.\n");

    return 0;
}
