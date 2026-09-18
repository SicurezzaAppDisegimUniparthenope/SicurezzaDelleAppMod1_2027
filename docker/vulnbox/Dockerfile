# Immagine amd64 con toolchain multilib: gli esempi (32-bit, come nelle
# slide: registri EAX/EBX, syscall int 0x80) sono compilati con gcc -m32
# ed eseguiti come binari i386 sotto il kernel IA32-compat del sistema.
# Su un host x86_64 reale (Intel Mac, Windows, Linux x86_64) tutto gira
# NATIVO: nessuna emulazione, ASLR reale. Su host arm64 (Apple Silicon) il
# container amd64 stesso gira via emulazione QEMU/Rosetta (gestita
# automaticamente da Docker/Podman Desktop): stesso limite noto già
# presente con l'immagine i386 pura (vedi solutions/14-countermeasure-aslr),
# non introdotto da questa scelta.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Pacchetti amd64 "normali", installati PRIMA di abilitare l'architettura
# i386 sotto: farlo nello stesso comando può portare apt a risolvere
# ambiguamente alcuni di questi (es. python3) anche in variante i386,
# rompendo poi la risoluzione delle wheel precompilate di pip.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gdb git curl ca-certificates nano vim-tiny \
        python3 python3-pip python3-venv python3-dev \
        openssh-server sudo strace ltrace file binutils \
        socat netcat-traditional \
        cmake ninja-build libssl-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Toolchain multilib (32 bit), in un comando separato dai pacchetti amd64
# sopra, per lo stesso motivo.
RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
        gcc-multilib g++-multilib \
    && rm -rf /var/lib/apt/lists/*

# Il pip di Debian bookworm (23.0.1) non riconosce i tag manylinux più
# recenti delle wheel precompilate delle dipendenze di pwntools/paramiko
# (cryptography, bcrypt, pynacl): senza aggiornarlo, prova a ricompilarle
# da sorgente (bcrypt richiede un compilatore Rust, assente).
RUN pip3 install --break-system-packages --no-cache-dir --upgrade pip \
    && pip3 install --break-system-packages --no-cache-dir pwntools ropper

# PEDA: estensione GDB leggera (puro Python, nessuna dipendenza compilata),
# più affidabile di pwndbg da compilare sotto emulazione i386/QEMU.
RUN git clone --depth 1 https://github.com/longld/peda.git /opt/peda

# "student": account senza sudo, usato per gli esercizi (stessi permessi
# di un utente non privilegiato del sistema target). "vulnbox": account con
# sudo NOPASSWD, per il docente/setup (installare pacchetti, ispezionare il
# sistema, ecc.).
RUN useradd -m -s /bin/bash student \
    && echo 'student:student' | chpasswd \
    && echo "source /opt/peda/peda.py" > /home/student/.gdbinit \
    && echo 'export PATH="$HOME/bin:$PATH"' >> /home/student/.bashrc \
    && chown student:student /home/student/.gdbinit /home/student/.bashrc \
    && useradd -m -s /bin/bash vulnbox \
    && echo 'vulnbox:vulnbox' | chpasswd \
    && usermod -aG sudo vulnbox \
    && echo 'vulnbox ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/vulnbox \
    && echo "source /opt/peda/peda.py" > /home/vulnbox/.gdbinit \
    && echo 'export PATH="$HOME/bin:$PATH"' >> /home/vulnbox/.bashrc \
    && chown vulnbox:vulnbox /home/vulnbox/.gdbinit /home/vulnbox/.bashrc

RUN mkdir -p /var/run/sshd /home/student/src \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Copia gli esempi nell'immagine: così l'immagine pubblicata (ghcr.io) è
# autosufficiente, senza dover clonare il repo (l'entrypoint li ricompila
# comunque a ogni avvio — se il docente monta un ./src aggiornato come
# bind mount, quello ha la precedenza automaticamente sovrascrivendo
# questa copia).
COPY src/ /home/student/src/
RUN chown -R student:student /home/student/src

# Consente ptrace (necessario a gdb) senza disabilitare del tutto seccomp:
# va comunque abbinato a `cap_add: SYS_PTRACE` nel docker-compose.yml.
RUN echo 'kernel.yama.ptrace_scope = 0' > /etc/sysctl.d/10-ptrace.conf || true

COPY vuln-gcc /usr/local/bin/vuln-gcc
COPY run-noaslr /usr/local/bin/run-noaslr
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/vuln-gcc /usr/local/bin/run-noaslr /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
