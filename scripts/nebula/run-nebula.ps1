<#
.SYNOPSIS
    Installa QEMU (se necessario) e avvia la VM Nebula di exploit.education su Windows.

.DESCRIPTION
    Nebula e' distribuita solo come ISO x86 (32 bit) avviabile direttamente
    (nessuna installazione richiesta). Viene sempre eseguita tramite
    emulazione della CPU x86: nativa/accelerata (WHPX) su host x86_64,
    via TCG (piu' lenta) su host ARM64.

    NOTA: a differenza di Phoenix, il progetto non pubblica un comando QEMU
    ufficiale per Nebula: i parametri di rete/scheda di rete qui sotto sono
    quelli usati piu' comunemente dalla community. Se dopo il boot la VM non
    ottiene un IP via DHCP, prova a cambiare -NicModel (rtl8139 -> e1000 o pcnet).

.PARAMETER Gui
    Avvia con finestra grafica QEMU. Se omesso, la VM parte headless.

.PARAMETER Port
    Porta locale per il forwarding SSH (default: 2223).

.PARAMETER Mem
    RAM della VM (default: 512M).

.PARAMETER NicModel
    Modello di scheda di rete QEMU (default: rtl8139).

.EXAMPLE
    .\run-nebula.ps1
    Avvia Nebula headless con le impostazioni di default.

.NOTES
    Una volta avviata: ssh -p <Port> level00@127.0.0.1   (password: level00)
#>

[CmdletBinding()]
param(
    [switch]$Gui,
    [int]$Port = 2223,
    [string]$Mem = "512M",
    [string]$NicModel = "rtl8139"
)

$ErrorActionPreference = "Stop"

$LogDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir "nebula-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
try {
    Start-Transcript -Path $LogFile -Append | Out-Null
    Write-Host "==> Log dettagliato salvato in: $LogFile"
} catch {
    Write-Warning "Impossibile avviare il log su file: $_"
}

$NebulaVersion = "v5.0.0"
$IsoName = "exploit-exercises-nebula-5.iso"
$IsoSha1 = "e82f807be06100bf3e048f82e899fb1fecc24e3a"
$InstallDir = Join-Path $env:USERPROFILE ".exploit-education\nebula"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

$HostIsArm64 = ($env:PROCESSOR_ARCHITECTURE -eq "ARM64")
$Native = -not $HostIsArm64
Write-Host "==> Nebula gira come guest x86 (32 bit) $(if ($Native) {'(accelerata)'} else {'(emulata via TCG, piu lenta)'})"

# ---------------------------------------------------------------------------
# 1) Installazione QEMU
# ---------------------------------------------------------------------------
function Get-QemuExe($binName) {
    $cmd = Get-Command $binName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $fallback = Join-Path "C:\Program Files\qemu" $binName
    if (Test-Path $fallback) { return $fallback }
    return $null
}

function Install-Qemu {
    if ((Get-QemuExe "qemu-system-i386.exe") -or (Get-QemuExe "qemu-system-x86_64.exe")) {
        Write-Host "==> QEMU gia' installato."
        return
    }
    Write-Host "==> Installazione di QEMU..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id=SoftwareFreedomConservancy.QEMU -e --accept-source-agreements --accept-package-agreements
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install qemu -y
    } else {
        Write-Error "Installa winget (App Installer) o Chocolatey, oppure QEMU manualmente da https://qemu.weilnetz.de/w64/ e rilancia lo script."
        exit 1
    }
}
Install-Qemu

$QemuExe = Get-QemuExe "qemu-system-i386.exe"
if (-not $QemuExe) { $QemuExe = Get-QemuExe "qemu-system-x86_64.exe" }
if (-not $QemuExe) {
    Write-Error "Impossibile trovare qemu-system-i386/qemu-system-x86_64 dopo l'installazione. Riavvia il terminale o verifica il PATH."
    exit 1
}

# ---------------------------------------------------------------------------
# 2) Download ISO
# ---------------------------------------------------------------------------
$IsoPath = Join-Path $InstallDir $IsoName
if (-not (Test-Path $IsoPath)) {
    Write-Host "==> Download ISO Nebula (~450MB)..."
    Invoke-WebRequest -Uri "https://github.com/ExploitEducation/Nebula/releases/download/$NebulaVersion/$IsoName" -OutFile "$IsoPath.part"
    Move-Item "$IsoPath.part" $IsoPath
}

$ActualSha1 = (Get-FileHash -Algorithm SHA1 -Path $IsoPath).Hash.ToLower()
if ($ActualSha1 -ne $IsoSha1) {
    Write-Warning "SHA1 dell'ISO non corrisponde a quello atteso!"
    Write-Warning "  atteso:  $IsoSha1"
    Write-Warning "  trovato: $ActualSha1"
    Write-Warning "Il file potrebbe essere corrotto: cancella $IsoPath e riprova."
    exit 1
}

# ---------------------------------------------------------------------------
# 3) Avvio QEMU
# ---------------------------------------------------------------------------
$DisplayArgs = @()
if (-not $Gui) { $DisplayArgs = @("-nographic") }

$AccelArgs = @()
if ($Native -and (Test-Path "C:\Windows\System32\WindowsHypervisorPlatform.dll")) {
    $AccelArgs = @("-accel", "whpx,kernel-irqchip=off")
}

Write-Host "==> Avvio Nebula in modalita' $(if ($Gui) {'GUI'} else {'headless'})"
Write-Host "==> Attendere il boot, poi: ssh -p $Port level00@127.0.0.1   (password: level00)"
if (-not $Gui) { Write-Host "==> (headless: per uscire dalla console usa Ctrl-A poi X)" }

& $QemuExe @AccelArgs `
    -m $Mem `
    -cdrom $IsoPath `
    -boot d `
    -netdev "user,id=n0,hostfwd=tcp:127.0.0.1:$Port-:22" `
    -device "$NicModel,netdev=n0" `
    @DisplayArgs
$QemuExitCode = $LASTEXITCODE

try { Stop-Transcript | Out-Null } catch {}
exit $QemuExitCode
