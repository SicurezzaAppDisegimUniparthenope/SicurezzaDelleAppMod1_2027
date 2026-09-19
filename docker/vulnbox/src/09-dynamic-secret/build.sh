#!/bin/sh
# Compilato SENZA -g (niente simboli di debug: slide 20, "note that we
# have not debug data in the object files") e SENZA -fno-stack-protector
# (qui non ci interessa il buffer overflow, solo l'offuscamento statico).
# BINDIR/CC e BINDIR64/CC64 arrivano dall'entrypoint (bin/i386+"gcc -m32"
# e bin/x64+"gcc -m64" su amd64; bin/arm64+"gcc" su arm64, identici sui
# due lati, nessuna seconda variante da produrre).
set -e
${CC:-gcc -m32} -no-pie -o "$BINDIR/guessmyname2" guessmyname2.c
if [ -n "$CC64" ] && [ "$BINDIR64" != "$BINDIR" ]; then
    $CC64 -no-pie -o "$BINDIR64/guessmyname2" guessmyname2.c
fi
