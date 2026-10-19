#!/bin/sh
# Stesso sorgente, due binari con NX diversa (slide 9: "gcc allows us to
# enable or disable NX flag on building"), per il confronto live.
# BINDIR/CC e BINDIR64/CC64 arrivano dall'entrypoint (bin/i386+"gcc -m32"
# e bin/x64+"gcc -m64" su amd64; bin/arm64+"gcc" su arm64, identici sui
# due lati, nessuna seconda variante da produrre).
set -e
${CC:-gcc -m32} -g -fno-stack-protector -no-pie -z execstack -o "$BINDIR/vuln-nx-off" vuln.c
${CC:-gcc -m32} -g -fno-stack-protector -no-pie -z noexecstack -o "$BINDIR/vuln-nx-on" vuln.c
if [ -n "$CC64" ] && [ "$BINDIR64" != "$BINDIR" ]; then
    $CC64 -g -fno-stack-protector -no-pie -z execstack -o "$BINDIR64/vuln-nx-off" vuln.c
    $CC64 -g -fno-stack-protector -no-pie -z noexecstack -o "$BINDIR64/vuln-nx-on" vuln.c
fi
