/*
 * Countermeasure: mitigazione delle vulnerabilità di format string.
 * Basato su "SS_2.2 - Format-string vulnerabilities.pptx", slide 25
 * ("Mitigations"): l'unica differenza tra le due versioni compilate da
 * build.sh è come l'input viene passato a printf.
 *
 * Versione vulnerabile: printf(buf)      <- l'input E' la format string
 * Versione sicura:      printf("%s",buf) <- l'input e' SOLO un argomento
 *
 * Con la versione sicura, un payload come "%n" o "AAAA.%7$x" viene
 * semplicemente stampato così com'è, senza alcun effetto su stack/memoria.
 */
#include <stdio.h>
#include <unistd.h>

int flag = 0;   /* stesso obiettivo dell'esempio 02: farla diventare != 0 */

void vulnerable(void) {
    char buf[256];
    ssize_t n = read(0, buf, sizeof(buf) - 1);
    if (n <= 0) {
        return;
    }
    buf[n] = '\0';

#ifdef SAFE
    printf("%s", buf);   /* sicuro: l'input e' un argomento, non la format string */
#else
    printf(buf);         /* vulnerabile: l'input dell'utente è la format string */
#endif
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
