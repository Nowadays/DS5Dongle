# Reflash le dongle DS5 et restaure la config automatiquement.
#
# Pourquoi : le uf2 genere par le SDK contient le bloc workaround RP2350-E10
# a 0x10FFFF00 (fin d'une flash 16 Mo) ; sur la flash 4 Mo du Pico 2 W il
# s'aliase sur le dernier secteur = le secteur de config -> la config est
# effacee a CHAQUE reflash. Ce script sauvegarde la config avant, reflashe,
# puis la restaure et re-enumere l'interface clavier.
#
# Usage : powershell -File tools\flash-and-restore.ps1
#         (dongle branche, manette connectee ; appuyer sur PS quand demande)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$uf2 = Join-Path $repo 'build\standard\ds5-bridge.uf2'
$py = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$configTool = Join-Path $PSScriptRoot 'config_tool.py'

if (-not (Test-Path $uf2)) { throw "uf2 introuvable: $uf2 (build d'abord)" }

Write-Host "[1/5] Sauvegarde de la config actuelle..."
$cfgLines = & $py $configTool get | Select-String '^\s+(\w+)\s+=\s+(\S+)' | ForEach-Object {
    $n = $_.Matches[0].Groups[1].Value; $v = $_.Matches[0].Groups[2].Value
    if ($n -ne 'config_version') { "$n=$v" }
}
Write-Host ("  " + ($cfgLines -join ' '))

Write-Host "[2/5] Reboot vers BOOTSEL..."
& $py (Join-Path $PSScriptRoot 'reboot_bootsel.py') | Out-Null

Write-Host "[3/5] Attente du lecteur RP2350 et copie du firmware..."
$deadline = (Get-Date).AddMinutes(3)
$flashed = $false
while ((Get-Date) -lt $deadline) {
    $vol = Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel -eq 'RP2350' -and $_.DriveLetter }
    if ($vol) { Copy-Item $uf2 "$($vol.DriveLetter):\" -Force; $flashed = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $flashed) { throw "lecteur RP2350 jamais apparu" }
Write-Host "  Firmware copie."

Write-Host "[4/5] Attente de la reconnexion (appuie sur PS si la manette dort)..."
$deadline = (Get-Date).AddMinutes(5)
$back = $false
while ((Get-Date) -lt $deadline) {
    if (Get-PnpDevice | Where-Object { $_.InstanceId -like '*VID_054C*MI_03*' -and $_.Status -eq 'OK' -and $_.Class -eq 'HIDClass' }) { $back = $true; break }
    Start-Sleep -Seconds 3
}
if (-not $back) { throw "dongle jamais re-enumere (manette non reconnectee ?)" }
Start-Sleep -Seconds 2

Write-Host "[5/5] Restauration de la config + reconnect USB..."
& $py $configTool set @cfgLines | Out-Null
@'
import hid, time
time.sleep(1)
cand = [d for d in hid.enumerate(0x054C) if d["product_id"] in (0x0CE6, 0x0DF2)
        and d.get("usage_page") == 0x01 and d.get("usage") == 0x05]
dev = hid.device(); dev.open_path(cand[0]["path"])
dev.send_feature_report(bytes([0xF6, 0x03]) + bytes(62))
dev.close()
'@ | & $py -
Start-Sleep -Seconds 5
$kbd = Get-PnpDevice | Where-Object { $_.InstanceId -like '*VID_054C*MI_04*' -and $_.Status -eq 'OK' -and $_.Class -eq 'Keyboard' }
if ($kbd) { Write-Host "OK: reflash termine, config restauree, interface clavier presente." }
else { Write-Warning "Reflash OK mais interface clavier absente - verifier enable_wake avec config_tool.py get" }
