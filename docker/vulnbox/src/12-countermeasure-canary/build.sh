#!/bin/sh
# Stesso sorgente, due binari con canary diversa (slide 13: opzione gcc
# -fstack-protector), per il confronto live.
set -e
gcc -m32 -g -fno-stack-protector -no-pie -z execstack -o "$BINDIR/vuln-canary-off" vuln.c
gcc -m32 -g -fstack-protector-all -no-pie -z execstack -o "$BINDIR/vuln-canary-on" vuln.c
