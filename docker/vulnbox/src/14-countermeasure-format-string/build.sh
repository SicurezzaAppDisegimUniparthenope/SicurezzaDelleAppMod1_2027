#!/bin/sh
# Stesso sorgente, due binari: vulnerabile (printf(buf)) e sicuro
# (printf("%s", buf), via -DSAFE), per il confronto live.
set -e
gcc -m32 -g -fno-stack-protector -no-pie -o "$BINDIR/vuln-format-off" vuln.c
gcc -m32 -g -fno-stack-protector -no-pie -DSAFE -o "$BINDIR/vuln-format-on" vuln.c
