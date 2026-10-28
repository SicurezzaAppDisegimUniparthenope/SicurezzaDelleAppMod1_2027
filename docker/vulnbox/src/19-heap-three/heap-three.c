/*
 * Sorgente invariato di phoenix/heap-three (exploit.education), vedi
 * "Lezione 6 - HEAP-BASED Buffer OVERFLOW.pptx". A differenza degli altri
 * esempi di questa cartella, QUESTO livello non compila con vuln-gcc: il
 * commento originale sotto dice che è "linked against" dlmalloc 2.7.2
 * (malloc-2.7.2.c, accluso in questa cartella, stesso SHA1 indicato nel
 * commento) — la glibc di Debian bookworm (2.36) ha invece protezioni
 * sull'unlink che bloccano l'attacco descritto nelle slide. build.sh
 * compila malloc-2.7.2.c come oggetto e lo linka con heap-three.c, così il
 * binario usa quella vecchia malloc al posto di quella di sistema (stessa
 * tecnica di collegamento usata a monte da Phoenix). Verificato: con
 * questo collegamento l'unlink() di dlmalloc non ha i controlli di
 * integrità introdotti nelle glibc moderne.
 * SOLO i386 (vedi anche il commento originale sotto): niente binario né
 * exploit per amd64-64/arm64, per lo stesso motivo indicato da Phoenix
 * stesso — con indirizzi a 64 bit l'attacco a unlink richiederebbe una
 * strategia diversa, non trattata nella lezione.
 */

/*
 * phoenix/heap-three, by https://exploit.education
 *
 * This level is linked against ftp://gee.cs.oswego.edu/pub/misc/malloc-2.7.2.c
 * version 2.7.2, with a SHA1 sum of 407329d164e4989b59b9a828760acb720dc5c7db
 * more commonly known as "dlmalloc", Doug Lea Malloc
 *
 * Can you hijack flow control, and execute winner()? Afterwards, how
 * about your own code? This level is solvable on Linux i386 easily enough,
 * as for other architectures, it may not be possible, or may require some
 * creativity - let me know what you come up with :)
 *
 * My friend told me that nothing rhymes with orange.
 * I told them, "No, it doesn't".
 *
 * Or, more seriously, https://www.youtube.com/watch?v=lPcR5RVXHMg
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

void winner() {
  printf("Level was successfully completed at @ %ld seconds past the Epoch\n",
      time(NULL));
}

int main(int argc, char **argv) {
  char *a, *b, *c;

  a = malloc(32);
  b = malloc(32);
  c = malloc(32);

  strcpy(a, argv[1]);
  strcpy(b, argv[2]);
  strcpy(c, argv[3]);

  free(c);
  free(b);
  free(a);

  printf("dynamite failed?\n");
}
