#!/bin/sh
set -e

# Idempotente: ssh-keygen -A salta le chiavi già presenti (rigenerate anche
# se create durante il build, per sicurezza in caso di rebuild parziali).
ssh-keygen -A

# Compila gli esempi montati in /home/student/src dentro /home/student/bin.
# Eseguito ad ogni avvio (non a build time) perché src/ arriva da un bind
# mount: così riflette sempre i sorgenti correnti sull'host.
#
# Se una sottocartella contiene un build.sh, viene eseguito lui (usato dagli
# esempi che devono produrre più binari con protezioni diverse per un
# confronto live, es. NX on/off, canary on/off). Altrimenti si applica il
# comportamento di default: ogni .c compilato con le protezioni disattivate
# di vuln-gcc.
mkdir -p /home/student/bin
: > /var/log/vulnbox-build.log
for dir in /home/student/src/*/; do
    [ -d "$dir" ] || continue
    if [ -x "$dir/build.sh" ]; then
        if (cd "$dir" && BINDIR=/home/student/bin ./build.sh) >>/var/log/vulnbox-build.log 2>&1; then
            echo "[vulnbox] build.sh ok: $dir" >>/var/log/vulnbox-build.log
        else
            echo "[vulnbox] ERRORE build.sh: $dir" >>/var/log/vulnbox-build.log
        fi
        continue
    fi
    for src in "$dir"*.c; do
        [ -e "$src" ] || continue
        name="$(basename "$src" .c)"
        if gcc -m32 -g -fno-stack-protector -z execstack -no-pie \
            -o "/home/student/bin/$name" "$src" >>/var/log/vulnbox-build.log 2>&1; then
            echo "[vulnbox] compilato: $name" >>/var/log/vulnbox-build.log
        else
            echo "[vulnbox] ERRORE compilazione: $src" >>/var/log/vulnbox-build.log
        fi
    done
done
chown -R student:student /home/student/bin
chmod -R 755 /home/student/bin

# Permette a vulnbox (docente) di attraversare la home di student e
# lanciare i binari in ~student/bin (utile per preparare/verificare gli
# exploit delle soluzioni con gli stessi path degli studenti).
chmod 755 /home/student

exec /usr/sbin/sshd -D -e
