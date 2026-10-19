#!/bin/sh
# Stesso sorgente, due binari con canary diversa (slide 13: opzione gcc
# -fstack-protector), per il confronto live.
# BINDIR/CC e BINDIR64/CC64 arrivano dall'entrypoint (bin/i386+"gcc -m32"
# e bin/x64+"gcc -m64" su amd64; bin/arm64+"gcc" su arm64, identici sui
# due lati, nessuna seconda variante da produrre).
set -e
${CC:-gcc -m32} -g -fno-stack-protector -no-pie -z execstack -o "$BINDIR/vuln-canary-off" vuln.c
${CC:-gcc -m32} -g -fstack-protector-all -no-pie -z execstack -o "$BINDIR/vuln-canary-on" vuln.c
if [ -n "$CC64" ] && [ "$BINDIR64" != "$BINDIR" ]; then
    $CC64 -g -fno-stack-protector -no-pie -z execstack -o "$BINDIR64/vuln-canary-off" vuln.c
    $CC64 -g -fstack-protector-all -no-pie -z execstack -o "$BINDIR64/vuln-canary-on" vuln.c
fi
