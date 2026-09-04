#!/usr/bin/env bash
#
# Installa QEMU (se necessario) e avvia la VM Phoenix di exploit.education.
# Supporta macOS (Intel/Apple Silicon) e Linux (distro basate su apt o dnf/yum).
#
# Uso:
#   ./run-phoenix.sh [--headless|--gui] [--port PORT] [--mem SIZE] [--arch amd64|arm64]
#
# Accesso una volta avviata:
#   ssh -p <PORT> user@127.0.0.1   (password: user)
#   ssh -p <PORT> root@127.0.0.1   (password: root)

set -euo pipefail

PHOENIX_VERSION="v1.0.0-alpha-3"
INSTALL_DIR="${PHOENIX_HOME:-$HOME/.exploit-education/phoenix}"
SSH_PORT="${SSH_PORT:-2222}"
MEM="${MEM:-1024M}"
HEADLESS=1
ARCH_OVERRIDE=""

usage() {
  cat <<EOF
Uso: $0 [opzioni]

Scarica (se necessario), installa QEMU e avvia la VM Phoenix (exploit.education).

Opzioni:
  --headless      Avvia senza finestra grafica, output su console (default)
  --gui           Avvia con finestra grafica QEMU
  --port PORT     Porta locale per il forwarding SSH (default: 2222)
  --mem SIZE      RAM della VM, es. 1024M / 2G (default: 1024M)
  --arch ARCH     Forza l'architettura dell'immagine: amd64 | arm64
                  (default: auto-rilevata dall'host)
  -h, --help      Mostra questo aiuto

Una volta avviata:
  ssh -p PORT user@127.0.0.1   (password: user)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --headless) HEADLESS=1; shift ;;
    --gui) HEADLESS=0; shift ;;
    --port) SSH_PORT="$2"; shift 2 ;;
    --mem) MEM="$2"; shift 2 ;;
    --arch) ARCH_OVERRIDE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opzione sconosciuta: $1" >&2; usage; exit 1 ;;
  esac
done

OS="$(uname -s)"
HOST_ARCH_RAW="$(uname -m)"

case "$HOST_ARCH_RAW" in
  x86_64|amd64) HOST_ARCH="amd64" ;;
  arm64|aarch64) HOST_ARCH="arm64" ;;
  *) echo "Architettura host non supportata: $HOST_ARCH_RAW" >&2; exit 1 ;;
esac

ARCH="$HOST_ARCH"
[[ -n "$ARCH_OVERRIDE" ]] && ARCH="$ARCH_OVERRIDE"
NATIVE=0
[[ "$ARCH" == "$HOST_ARCH" ]] && NATIVE=1

echo "==> Sistema host: $OS/$HOST_ARCH_RAW - architettura immagine Phoenix: $ARCH $( [[ $NATIVE -eq 1 ]] && echo '(nativa)' || echo '(emulata via TCG, piu lenta)' )"

# ---------------------------------------------------------------------------
# 1) Installazione QEMU
# ---------------------------------------------------------------------------
install_qemu() {
  if command -v qemu-system-x86_64 >/dev/null 2>&1 && command -v qemu-system-aarch64 >/dev/null 2>&1; then
    echo "==> QEMU gia' installato."
    return
  fi
  echo "==> Installazione di QEMU..."
  if [[ "$OS" == "Darwin" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      echo "Homebrew non trovato. Installalo da https://brew.sh e rilancia lo script." >&2
      exit 1
    fi
    brew install qemu
  elif [[ "$OS" == "Linux" ]]; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y qemu-system-x86 qemu-system-arm qemu-utils
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y qemu-system-x86 qemu-system-aarch64 qemu-img
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y qemu-system-x86 qemu-system-aarch64 qemu-img
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --needed qemu-full
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper install -y qemu-x86 qemu-arm
    else
      echo "Package manager non riconosciuto. Installa QEMU manualmente (qemu-system-x86_64 e qemu-system-aarch64)." >&2
      exit 1
    fi
  else
    echo "Sistema operativo non supportato da questo script: $OS" >&2
    exit 1
  fi
}
install_qemu

QEMU_BIN="qemu-system-x86_64"
[[ "$ARCH" == "arm64" ]] && QEMU_BIN="qemu-system-aarch64"
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
  echo "Impossibile trovare $QEMU_BIN dopo l'installazione." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2) Download ed estrazione immagine
# ---------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

ARCHIVE="exploit-education-phoenix-${ARCH}-${PHOENIX_VERSION}.tar.xz"
URL="https://github.com/ExploitEducation/Phoenix/releases/download/${PHOENIX_VERSION}/${ARCHIVE}"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "==> Download immagine Phoenix ($ARCH)... (alcune centinaia di MB, puo' richiedere tempo)"
  curl -L --fail -o "${ARCHIVE}.part" "$URL"
  mv "${ARCHIVE}.part" "$ARCHIVE"
fi

EXTRACT_DIR="extracted-${ARCH}"
if [[ ! -d "$EXTRACT_DIR" ]] || [[ -z "$(ls -A "$EXTRACT_DIR" 2>/dev/null)" ]]; then
  echo "==> Estrazione..."
  mkdir -p "$EXTRACT_DIR"
  tar -xf "$ARCHIVE" -C "$EXTRACT_DIR"
fi

KERNEL="$(find "$EXTRACT_DIR" -type f -name 'vmlinuz-*' | head -n1)"
INITRD="$(find "$EXTRACT_DIR" -type f -name 'initrd.img-*' | head -n1)"
DISK="$(find "$EXTRACT_DIR" -type f -name '*.qcow2' | head -n1)"

if [[ -z "$KERNEL" || -z "$INITRD" || -z "$DISK" ]]; then
  echo "Non trovo kernel/initrd/disco dentro $INSTALL_DIR/$EXTRACT_DIR." >&2
  echo "Controlla il contenuto dell'archivio: potrebbe essere cambiato lo schema dei nomi file." >&2
  exit 1
fi

echo "==> Kernel: $KERNEL"
echo "==> Initrd: $INITRD"
echo "==> Disco:  $DISK"

# ---------------------------------------------------------------------------
# 3) Avvio QEMU
# ---------------------------------------------------------------------------
DISPLAY_ARGS=()
APPEND="root=/dev/vda1"
if [[ "$HEADLESS" -eq 1 ]]; then
  DISPLAY_ARGS=(-nographic)
  APPEND="root=/dev/vda1 console=ttyS0"
fi

ACCEL_ARGS=()
CPU_ARGS=()
if [[ "$NATIVE" -eq 1 ]]; then
  if [[ "$OS" == "Darwin" ]]; then
    ACCEL_ARGS=(-accel hvf)
    CPU_ARGS=(-cpu host)
  elif [[ "$OS" == "Linux" && -e /dev/kvm ]]; then
    ACCEL_ARGS=(-accel kvm)
    CPU_ARGS=(-cpu host)
  fi
elif [[ "$ARCH" == "arm64" ]]; then
  CPU_ARGS=(-cpu cortex-a57)
fi

MACHINE_ARGS=()
[[ "$ARCH" == "arm64" ]] && MACHINE_ARGS=(-M virt)

echo "==> Avvio Phoenix in modalita' $( [[ $HEADLESS -eq 1 ]] && echo headless || echo GUI )"
echo "==> Una volta avviata: ssh -p $SSH_PORT user@127.0.0.1   (password: user)"
[[ "$HEADLESS" -eq 1 ]] && echo "==> (headless: per uscire dalla console seriale usa Ctrl-A poi X)"

exec "$QEMU_BIN" \
  "${MACHINE_ARGS[@]}" \
  "${ACCEL_ARGS[@]}" \
  "${CPU_ARGS[@]}" \
  -kernel "$KERNEL" \
  -initrd "$INITRD" \
  -append "$APPEND" \
  -m "$MEM" \
  -netdev "user,id=unet,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
  -device virtio-net,netdev=unet \
  -drive "file=$DISK,if=virtio,format=qcow2,index=0" \
  "${DISPLAY_ARGS[@]}"
