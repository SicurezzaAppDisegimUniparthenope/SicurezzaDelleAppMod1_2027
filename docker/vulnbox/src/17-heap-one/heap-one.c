/*
 * Sorgente invariato di phoenix/heap-one (exploit.education), vedi
 * "Lezione 6 - HEAP-BASED Buffer OVERFLOW.pptx". Compilare con vuln-gcc
 * (i386/x64) o vuln-gcc (arm64) — nessun flag speciale, nessun build.sh.
 * LEVELNAME è normalmente passato da Phoenix con -D al build: qui è
 * fissato direttamente nel sorgente. Il commento "phoenix/heap-zero" nel
 * blocco sotto è un copia-incolla rimasto nel sorgente ufficiale di
 * Phoenix stesso (verificato scaricandolo da ExploitEducation/Phoenix):
 * lasciato invariato per fedeltà all'originale, BANNER qui non è comunque
 * mai stampato (vedi main()).
 */

/*
 * phoenix/heap-zero, by https://exploit.education
 *
 * Can you hijack flow control?
 *
 * Which vegetable did Noah leave off the Ark?
 * Leeks
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define LEVELNAME "phoenix/heap-one"

#define BANNER \
  "Welcome to " LEVELNAME ", brought to you by https://exploit.education"

struct heapStructure {
  int priority;
  char *name;
};

int main(int argc, char **argv) {
  struct heapStructure *i1, *i2;

  i1 = malloc(sizeof(struct heapStructure));
  i1->priority = 1;
  i1->name = malloc(8);

  i2 = malloc(sizeof(struct heapStructure));
  i2->priority = 2;
  i2->name = malloc(8);

  strcpy(i1->name, argv[1]);
  strcpy(i2->name, argv[2]);

  printf("and that's a wrap folks!\n");
}

void winner() {
  printf(
      "Congratulations, you've completed this level @ %ld seconds past the "
      "Epoch\n",
      time(NULL));
}
