/*
 * Dynamic analysis - segreto offuscato, non più leggibile con
 * readelf/strings da solo.
 * Basato su "SS_1.3 - Static and Dynamic Analysis.pptx", slide 17-27:
 * il nome non è più una stringa in chiaro nel binario (è offuscato con
 * uno XOR banale), ma viene comunque deoffuscato in una variabile in
 * chiaro a runtime, osservabile con gdb (step-by-step nello stack) o con
 * ltrace (che intercetta la strcmp con l'argomento già deoffuscato).
 *
 * Compilato SENZA simboli di debug (vedi build.sh): "note that we have
 * not debug data in the object files" (slide 20).
 */
#include <stdio.h>
#include <string.h>

static const unsigned char secret_obf[] = {
    0x0c, 0x3b, 0x36, 0x3f, 0x28, 0x33, 0x3b
};
#define XOR_KEY 0x5A

static void deobfuscate(char *out, const unsigned char *in, size_t n) {
    size_t i;
    for (i = 0; i < n; i++) {
        out[i] = (char) (in[i] ^ XOR_KEY);
    }
    out[n] = '\0';
}

int main(void) {
    char guess[64];
    char secret[64];

    deobfuscate(secret, secret_obf, sizeof(secret_obf));

    printf("Indovina il mio nome: ");
    fflush(stdout);

    if (!fgets(guess, sizeof(guess), stdin)) {
        return 1;
    }
    guess[strcspn(guess, "\n")] = '\0';

    if (strcmp(guess, secret) == 0) {
        printf("Esatto! Complimenti.\n");
    } else {
        printf("Sbagliato, riprova.\n");
    }

    return 0;
}
