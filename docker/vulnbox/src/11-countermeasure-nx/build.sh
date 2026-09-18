#!/bin/sh
# Stesso sorgente, due binari con NX diversa (slide 9: "gcc allows us to
# enable or disable NX flag on building"), per il confronto live.
set -e
gcc -m32 -g -fno-stack-protector -no-pie -z execstack -o "$BINDIR/vuln-nx-off" vuln.c
gcc -m32 -g -fno-stack-protector -no-pie -z noexecstack -o "$BINDIR/vuln-nx-on" vuln.c
