#!/bin/sh
# heap-three va linkato contro la vecchia dlmalloc 2.7.2 (malloc-2.7.2.c,
# vedi commento in heap-three.c) invece della glibc di sistema, altrimenti
# l'attacco a unlink() delle slide è bloccato dai controlli di integrità
# introdotti nelle glibc moderne. Solo i386 (vedi heap-three.c): niente da
# fare su arm64 (CCDIR==CC64DIR li' e comunque qui serve sempre gcc -m32,
# non disponibile), e niente variante x64 nemmeno su amd64 (Phoenix stesso
# dichiara l'attacco non portabile direttamente su altre architetture).
set -e
case "${CC:-gcc -m32}" in
    *-m32*) ;;
    *) exit 0 ;;
esac
# L'oggetto intermedio va fuori da src/ (che a runtime e' un bind mount
# dell'host, spesso montato con permessi che non permettono di scriverci):
# usiamo una working dir temporanea invece della cartella corrente.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
${CC:-gcc -m32} -g -O0 -fno-stack-protector -no-pie -z execstack -c malloc-2.7.2.c -o "$WORK/malloc-2.7.2.o"
${CC:-gcc -m32} -g -O0 -fno-stack-protector -no-pie -z execstack -o "$BINDIR/heap-three" heap-three.c "$WORK/malloc-2.7.2.o"
