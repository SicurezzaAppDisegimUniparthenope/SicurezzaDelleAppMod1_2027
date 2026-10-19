#!/bin/sh
# Stesso sorgente, due binari: vulnerabile (printf(buf)) e sicuro
# (printf("%s", buf), via -DSAFE), per il confronto live.
# BINDIR/CC e BINDIR64/CC64 arrivano dall'entrypoint (bin/i386+"gcc -m32"
# e bin/x64+"gcc -m64" su amd64; bin/arm64+"gcc" su arm64, identici sui
# due lati, nessuna seconda variante da produrre).
set -e
${CC:-gcc -m32} -g -fno-stack-protector -no-pie -o "$BINDIR/vuln-format-off" vuln.c
${CC:-gcc -m32} -g -fno-stack-protector -no-pie -DSAFE -o "$BINDIR/vuln-format-on" vuln.c
if [ -n "$CC64" ] && [ "$BINDIR64" != "$BINDIR" ]; then
    $CC64 -g -fno-stack-protector -no-pie -o "$BINDIR64/vuln-format-off" vuln.c
    $CC64 -g -fno-stack-protector -no-pie -DSAFE -o "$BINDIR64/vuln-format-on" vuln.c
fi
