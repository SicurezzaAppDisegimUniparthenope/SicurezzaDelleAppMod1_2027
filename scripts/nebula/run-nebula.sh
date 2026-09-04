#!/usr/bin/env bash
#
# Installa QEMU (se necessario) e avvia la VM Nebula di exploit.education.
# Supporta macOS (Intel/Apple Silicon) e Linux (distro basate su apt o dnf/yum).
#
# Nebula e' distribuita SOLO come ISO x86 (32 bit) avviabile direttamente
# (nessuna installazione richiesta): l'ISO viene sempre eseguita tramite
# emulazione QEMU della CPU x86 (nativa su host x86_64, via TCG su host arm64
# come Apple Silicon: funziona ma piu' lenta).
#
# NOTA: a differenza di Phoenix, il progetto non pubblica un comando QEMU
# ufficiale per Nebula: i parametri di rete/scheda di rete qui sotto sono
# quelli usati piu' comunemente dalla community. Se dopo il boot la VM non
# ottiene un IP via DHCP, prova a cambiare il modello di scheda di rete
# (variabile NIC_MODEL sotto: rtl8139 -> e1000 o pcnet).
#
# Uso:
#   ./run-nebula.sh [--headless|--gui] [--port PORT] [--mem SIZE]
#
# Accesso una volta avviata:
#   ssh -p <PORT> level00@127.0.0.1   (password: level00)
#   ssh -p <PORT> nebula@127.0.0.1    (password: nebula, poi "sudo -s")

set -euo pipefail

NEBULA_VERSION="v5.0.0"
ISO_NAME="exploit-exercises-nebula-5.iso"
ISO_SHA1="e82f807be06100bf3e048f82e899fb1fecc24e3a"
INSTALL_DIR="${NEBULA_HOME:-$HOME/.exploit-education/nebula}"
SSH_PORT="${SSH_PORT:-2223}"
MEM="${MEM:-512M}"
NIC_MODEL="${NIC_MODEL:-rtl8139}"
HEADLESS=1

usage() {
  cat <<EOF
Uso: $0 [opzioni]

Scarica (se necessario), installa QEMU e avvia la VM Nebula (exploit.education).

Opzioni:
  --headless      Avvia senza finestra grafica, output su console (default)
  --gui           Avvia con finestra grafica QEMU
  --port PORT     Porta locale per il forwarding SSH (default: 2223)
  --mem SIZE      RAM della VM, es. 512M (default: 512M)
  -h, --help      Mostra questo aiuto

Una volta avviata (attendere il boot, 10-30s circa):
  ssh -p PORT level00@127.0.0.1   (password: level00)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --headless) HEADLESS=1; shift ;;
    --gui) HEADLESS=0; shift ;;
    --port) SSH_PORT="$2"; shift 2 ;;
    --mem) MEM="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opzione sconosciuta: $1" >&2; usage; exit 1 ;;
  esac
done

OS="$(uname -s)"
HOST_ARCH_RAW="$(uname -m)"
NATIVE=0
[[ "$HOST_ARCH_RAW" == "x86_64" || "$HOST_ARCH_RAW" == "amd64" ]] && NATIVE=1

echo "==> Sistema host: $OS/$HOST_ARCH_RAW - Nebula gira come guest x86 (32 bit) $( [[ $NATIVE -eq 1 ]] && echo '(accelerata)' || echo '(emulata via TCG, piu lenta)' )"

# ---------------------------------------------------------------------------
# 1) Installazione QEMU
# ---------------------------------------------------------------------------
install_qemu() {
  if command -v qemu-system-i386 >/dev/null 2>&1 || command -v qemu-system-x86_64 >/dev/null 2>&1; then
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
      sudo apt-get install -y qemu-system-x86 qemu-utils
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y qemu-system-x86 qemu-img
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y qemu-system-x86 qemu-img
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --needed qemu-full
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper install -y qemu-x86
    else
      echo "Package manager non riconosciuto. Installa QEMU manualmente (qemu-system-i386)." >&2
      exit 1
    fi
  else
    echo "Sistema operativo non supportato da questo script: $OS" >&2
    exit 1
  fi
}
install_qemu

QEMU_BIN="qemu-system-i386"
command -v "$QEMU_BIN" >/dev/null 2>&1 || QEMU_BIN="qemu-system-x86_64"
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
  echo "Impossibile trovare $QEMU_BIN dopo l'installazione." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2) Download ISO
# ---------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [[ ! -f "$ISO_NAME" ]]; then
  echo "==> Download ISO Nebula (~450MB)..."
  curl -L --fail -o "${ISO_NAME}.part" \
    "https://github.com/ExploitEducation/Nebula/releases/download/${NEBULA_VERSION}/${ISO_NAME}"
  mv "${ISO_NAME}.part" "$ISO_NAME"
fi

if command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA1="$(shasum -a1 "$ISO_NAME" | awk '{print $1}')"
elif command -v sha1sum >/dev/null 2>&1; then
  ACTUAL_SHA1="$(sha1sum "$ISO_NAME" | awk '{print $1}')"
else
  ACTUAL_SHA1=""
fi

if [[ -n "$ACTUAL_SHA1" && "$ACTUAL_SHA1" != "$ISO_SHA1" ]]; then
  echo "ATTENZIONE: SHA1 dell'ISO non corrisponde a quello atteso!" >&2
  echo "  atteso:  $ISO_SHA1" >&2
  echo "  trovato: $ACTUAL_SHA1" >&2
  echo "Il file potrebbe essere corrotto: cancella $INSTALL_DIR/$ISO_NAME e riprova." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 3) Avvio QEMU
# ---------------------------------------------------------------------------
DISPLAY_ARGS=()
[[ "$HEADLESS" -eq 1 ]] && DISPLAY_ARGS=(-nographic)

ACCEL_ARGS=()
if [[ "$NATIVE" -eq 1 ]]; then
  if [[ "$OS" == "Darwin" ]]; then
    ACCEL_ARGS=(-accel hvf)
  elif [[ "$OS" == "Linux" && -e /dev/kvm ]]; then
    ACCEL_ARGS=(-accel kvm)
  fi
fi

echo "==> Avvio Nebula in modalita' $( [[ $HEADLESS -eq 1 ]] && echo headless || echo GUI )"
echo "==> Attendere il boot, poi: ssh -p $SSH_PORT level00@127.0.0.1   (password: level00)"
[[ "$HEADLESS" -eq 1 ]] && echo "==> (headless: per uscire dalla console usa Ctrl-A poi X)"

exec "$QEMU_BIN" \
  "${ACCEL_ARGS[@]}" \
  -m "$MEM" \
  -cdrom "$ISO_NAME" \
  -boot d \
  -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22" \
  -device "${NIC_MODEL},netdev=n0" \
  "${DISPLAY_ARGS[@]}"
