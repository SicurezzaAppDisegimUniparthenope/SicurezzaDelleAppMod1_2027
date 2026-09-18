#!/bin/sh
# Compilato SENZA -g (niente simboli di debug: slide 20, "note that we
# have not debug data in the object files") e SENZA -fno-stack-protector
# (qui non ci interessa il buffer overflow, solo l'offuscamento statico).
set -e
gcc -m32 -no-pie -o "$BINDIR/guessmyname2" guessmyname2.c
