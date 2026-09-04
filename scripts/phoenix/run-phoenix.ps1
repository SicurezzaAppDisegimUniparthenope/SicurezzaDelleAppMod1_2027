<#
.SYNOPSIS
    Installa QEMU (se necessario) e avvia la VM Phoenix di exploit.education su Windows.

.DESCRIPTION
    Scarica l'immagine Phoenix ufficiale (amd64 o arm64), la estrae e la avvia
    con QEMU, con forwarding SSH sulla porta locale indicata.

.PARAMETER Gui
    Avvia con finestra grafica QEMU. Se omesso, la VM parte headless
    (output reindirizzato sulla console del terminale).

.PARAMETER Port
    Porta locale per il forwarding SSH (default: 2222).

.PARAMETER Mem
    RAM della VM, es. 1024M / 2G (default: 1024M).

.PARAMETER Arch
    Forza l'architettura dell'immagine: amd64 | arm64 (default: auto-rilevata).

.EXAMPLE
    .\run-phoenix.ps1
    Avvia Phoenix headless con le impostazioni di default.

.EXAMPLE
    .\run-phoenix.ps1 -Gui -Port 2200
    Avvia Phoenix con finestra grafica, SSH sulla porta 2200.

.NOTES
    Una volta avviata: ssh -p <Port> user@127.0.0.1   (password: user)
#>

[CmdletBinding()]
param(
    [switch]$Gui,
    [int]$Port = 2222,
    [string]$Mem = "1024M",
    [ValidateSet("amd64", "arm64")]
    [string]$Arch
)

$ErrorActionPreference = "Stop"

$LogDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogFile = Join-Path $LogDir "phoenix-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
try {
    Start-Transcript -Path $LogFile -Append | Out-Null
    Write-Host "==> Log dettagliato salvato in: $LogFile"
} catch {
    Write-Warning "Impossibile avviare il log su file: $_"
}

$PhoenixVersion = "v1.0.0-alpha-3"
$InstallDir = Join-Path $env:USERPROFILE ".exploit-education\phoenix"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# ---------------------------------------------------------------------------
# Rilevamento architettura
# ---------------------------------------------------------------------------
if (-not $Arch) {
    $Arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
}
$HostIsArm64 = ($env:PROCESSOR_ARCHITECTURE -eq "ARM64")
$Native = (($Arch -eq "arm64" -and $HostIsArm64) -or ($Arch -eq "amd64" -and -not $HostIsArm64))
Write-Host "==> Architettura immagine Phoenix: $Arch $(if ($Native) {'(nativa)'} else {'(emulata via TCG, piu lenta)'})"

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
    if ((Get-QemuExe "qemu-system-x86_64.exe") -and (Get-QemuExe "qemu-system-aarch64.exe")) {
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

$QemuBinName = if ($Arch -eq "arm64") { "qemu-system-aarch64.exe" } else { "qemu-system-x86_64.exe" }
$QemuExe = Get-QemuExe $QemuBinName
if (-not $QemuExe) {
    Write-Error "Impossibile trovare $QemuBinName dopo l'installazione. Riavvia il terminale o verifica il PATH."
    exit 1
}

# ---------------------------------------------------------------------------
# 2) Download ed estrazione immagine
# ---------------------------------------------------------------------------
$Archive = "exploit-education-phoenix-$Arch-$PhoenixVersion.tar.xz"
$Url = "https://github.com/ExploitEducation/Phoenix/releases/download/$PhoenixVersion/$Archive"
$ArchivePath = Join-Path $InstallDir $Archive
$ExtractDir = Join-Path $InstallDir "extracted-$Arch"

if (-not (Test-Path $ArchivePath)) {
    Write-Host "==> Download immagine Phoenix ($Arch)... (alcune centinaia di MB, puo' richiedere tempo)"
    Invoke-WebRequest -Uri $Url -OutFile "$ArchivePath.part"
    Move-Item "$ArchivePath.part" $ArchivePath
}

if (-not (Test-Path $ExtractDir) -or ((Get-ChildItem $ExtractDir -ErrorAction SilentlyContinue).Count -eq 0)) {
    Write-Host "==> Estrazione (richiede tar, incluso in Windows 10/11)..."
    New-Item -ItemType Directory -Force -Path $ExtractDir | Out-Null
    tar -xf $ArchivePath -C $ExtractDir
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Estrazione fallita. Assicurati che 'tar' sia disponibile (Windows 10 1803+ lo include di default)."
        exit 1
    }
}

$Kernel = Get-ChildItem -Path $ExtractDir -Recurse -Filter "vmlinuz-*" | Select-Object -First 1
$Initrd = Get-ChildItem -Path $ExtractDir -Recurse -Filter "initrd.img-*" | Select-Object -First 1
$Disk   = Get-ChildItem -Path $ExtractDir -Recurse -Filter "*.qcow2" | Select-Object -First 1

if (-not $Kernel -or -not $Initrd -or -not $Disk) {
    Write-Error "Non trovo kernel/initrd/disco dentro $ExtractDir. Controlla il contenuto dell'archivio."
    exit 1
}

Write-Host "==> Kernel: $($Kernel.FullName)"
Write-Host "==> Initrd: $($Initrd.FullName)"
Write-Host "==> Disco:  $($Disk.FullName)"

# ---------------------------------------------------------------------------
# 3) Avvio QEMU
# ---------------------------------------------------------------------------
$Append = "root=/dev/vda1"
$DisplayArgs = @()
if (-not $Gui) {
    $DisplayArgs = @("-nographic")
    $Append = "root=/dev/vda1 console=ttyS0"
}

$AccelArgs = @()
$CpuArgs = @()
if ($Native -and $Arch -eq "amd64" -and (Test-Path "C:\Windows\System32\WindowsHypervisorPlatform.dll")) {
    $AccelArgs = @("-accel", "whpx,kernel-irqchip=off")
    $CpuArgs = @("-cpu", "host")
} elseif ($Arch -eq "arm64" -and -not $Native) {
    $CpuArgs = @("-cpu", "cortex-a57")
}

$MachineArgs = @()
if ($Arch -eq "arm64") { $MachineArgs = @("-M", "virt") }

Write-Host "==> Avvio Phoenix in modalita' $(if ($Gui) {'GUI'} else {'headless'})"
Write-Host "==> Una volta avviata: ssh -p $Port user@127.0.0.1   (password: user)"
if (-not $Gui) { Write-Host "==> (headless: per uscire dalla console seriale usa Ctrl-A poi X)" }

& $QemuExe @MachineArgs @AccelArgs @CpuArgs `
    -kernel $Kernel.FullName `
    -initrd $Initrd.FullName `
    -append $Append `
    -m $Mem `
    -netdev "user,id=unet,hostfwd=tcp:127.0.0.1:$Port-:22" `
    -device virtio-net,netdev=unet `
    -drive "file=$($Disk.FullName),if=virtio,format=qcow2,index=0" `
    @DisplayArgs
$QemuExitCode = $LASTEXITCODE

try { Stop-Transcript | Out-Null } catch {}
exit $QemuExitCode
