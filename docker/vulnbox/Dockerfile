# Immagine multi-arch (amd64/arm64). Su amd64, gcc-multilib compila sia a
# 32 bit (-m32, default storico: come nelle slide, registri EAX/EBX,
# syscall int 0x80) sia a 64 bit (-m64) dallo STESSO gcc: l'entrypoint
# produce quindi per ogni esempio entrambi i binari, in sottocartelle
# separate di /home/student/bin/ (bin/i386/<nome> per il 32 bit, storico
# e invariato per compatibilità con gli exploit esistenti; bin/x64/<nome>
# per il 64 bit), in un'unica immagine/container, senza bisogno di due
# immagini separate. Su arm64 esiste solo la variante nativa a 64 bit
# (nessun flag), in bin/arm64/<nome>: arm64+32 (armhf) NON è supportato —
# verificato (spike P0, vedi TODO-multiarch.md) che gli host Apple
# Silicon non eseguono AArch32 a EL0 nella VM Docker/Podman, quindi qui
# arm64 usa un'immagine e un docker-compose.arm64.yml dedicati.
# Su un host la cui arch nativa corrisponde a TARGETARCH tutto gira NATIVO
# (nessuna emulazione, ASLR reale); altrimenti il container gira via
# emulazione QEMU/Rosetta (gestita automaticamente da Docker/Podman
# Desktop), con gli stessi limiti noti già documentati in README.md.
FROM debian:bookworm-slim

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Pacchetti "normali", installati PRIMA di abilitare l'architettura i386
# sotto: farlo nello stesso comando può portare apt a risolvere
# ambiguamente alcuni di questi (es. python3) anche in variante i386,
# rompendo poi la risoluzione delle wheel precompilate di pip.
# NB: "ltrace" NON è nell'elenco qui — vedi blocco sotto, non esiste per
# arm64 nei repo Debian bookworm (verificato: "apt-cache policy ltrace"
# non restituisce alcun candidato su arm64, a differenza di "strace" che
# è disponibile su entrambe le arch).
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gdb git curl ca-certificates nano vim-tiny \
        python3 python3-pip python3-venv python3-dev \
        openssh-server sudo strace file binutils \
        socat netcat-traditional \
        cmake ninja-build libssl-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Toolchain multilib i386 e ltrace, solo su amd64: la prima serve per
# compilare sia a 32 che a 64 bit con lo stesso gcc (non esiste un
# equivalente "gcc-multilib" per generare armhf da un host arm64, e
# comunque arm64+32 non è supportato, vedi sopra); ltrace non è
# disponibile come pacchetto per arm64 in Debian bookworm (vedi nota
# sopra) — su arm64 restano gdb e strace per l'analisi dinamica.
RUN set -e; \
    if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386 && apt-get update && apt-get install -y --no-install-recommends \
            gcc-multilib g++-multilib ltrace \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Fissa una volta per tutte, al build, i compilatori e le sottocartelle
# di output da usare per gli esempi vulnerabili (letti a runtime da
# vuln-gcc/vuln-gcc64/entrypoint.sh/build.sh): /etc/vulnbox-cc[-dir] è la
# variante di default (storica: 32 bit su amd64, in bin/i386/),
# /etc/vulnbox-cc64[-dir] la variante 64 bit esplicita (bin/x64/ su
# amd64). Su arm64 CC e CC64 coincidono (gcc nativo, bin/arm64/):
# l'entrypoint usa questa uguaglianza come segnale per NON duplicare
# inutilmente lo stesso binario in due sottocartelle.
RUN set -e; \
    case "$TARGETARCH" in \
        amd64) \
            echo 'gcc -m32' > /etc/vulnbox-cc; echo 'i386' > /etc/vulnbox-cc-dir; \
            echo 'gcc -m64' > /etc/vulnbox-cc64; echo 'x64' > /etc/vulnbox-cc64-dir ;; \
        arm64) \
            echo 'gcc' > /etc/vulnbox-cc; echo 'arm64' > /etc/vulnbox-cc-dir; \
            echo 'gcc' > /etc/vulnbox-cc64; echo 'arm64' > /etc/vulnbox-cc64-dir ;; \
        *) echo "Architettura non supportata: TARGETARCH=$TARGETARCH (vedi docker/vulnbox/TODO-multiarch.md)" >&2; exit 1 ;; \
    esac

# Il pip di Debian bookworm (23.0.1) non riconosce i tag manylinux più
# recenti delle wheel precompilate delle dipendenze di pwntools/paramiko
# (cryptography, bcrypt, pynacl): senza aggiornarlo, prova a ricompilarle
# da sorgente (bcrypt richiede un compilatore Rust, assente).
RUN pip3 install --break-system-packages --no-cache-dir --upgrade pip \
    && pip3 install --break-system-packages --no-cache-dir pwntools ropper \
    && pip3 install --break-system-packages --no-cache-dir "capstone==5.0.9"
# Il pin sopra forza capstone alla ultima stabile: senza, pip risolve da
# solo capstone 6.0.0a10 (pre-release/alpha, non l'ultima stabile 5.0.9),
# che ha rinominato CS_ARCH_ARM64 in CS_ARCH_AARCH64 - rompendo sia il
# comando ROPgadget standalone sia pwntools.ROP() su QUALSIASI binario
# arm64 (NameError: CS_ARCH_ARM64 is not defined), scoperto lavorando su
# 03-ret2libc/04-rop a 64 bit su arm64. Non influenza le build amd64
# (il codepath ARM64 di ROPgadget non viene mai eseguito lì).

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
COPY vuln-gcc64 /usr/local/bin/vuln-gcc64
COPY run-noaslr /usr/local/bin/run-noaslr
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /usr/local/bin/vuln-gcc /usr/local/bin/vuln-gcc64 /usr/local/bin/run-noaslr /entrypoint.sh

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
