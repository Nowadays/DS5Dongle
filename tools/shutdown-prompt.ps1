# Déclenché par le combo manette L1+L2+R1+R2 + Bas (Ctrl+Alt+Shift+S via le
# .lnk "Shutdown PC (manette)" du menu Démarrer).
# Ouvre un terminal avec compte à rebours ; l'extinction n'est lancée qu'à la
# fin du décompte. Annulation : touche, Ctrl+C, fermeture de la fenêtre, ou
# combo manette Droite (shutdown-cancel.ps1 signale l'événement nommé).
# -Test : décompte court et pas d'extinction réelle.
param([switch]$Test)

$log = Join-Path $PSScriptRoot 'shutdown-prompt.log'
"$(Get-Date -Format 'HH:mm:ss.fff') lance (pid=$PID, test=$Test)" | Out-File $log -Encoding utf8
trap {
    "$(Get-Date -Format 'HH:mm:ss.fff') EXCEPTION: $($_.Exception.GetType().Name): $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)" |
        Out-File $log -Append -Encoding utf8
    Write-Host "ERREUR: $($_.Exception.Message)" -ForegroundColor Red
    Start-Sleep -Seconds 10
    exit 1
}

$delay = if ($Test) { 5 } else { 30 }
$host.UI.RawUI.WindowTitle = "Extinction du PC"

# Événement partagé avec shutdown-cancel.ps1 ; purge d'un signal résiduel.
$cancelEvt = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::ManualReset, 'DS5Dongle_CancelShutdown')
$cancelEvt.Reset() | Out-Null

Write-Host ""
Write-Host "  ============================" -ForegroundColor Red
Write-Host "       EXTINCTION DU PC" -ForegroundColor Red
Write-Host "  ============================" -ForegroundColor Red
Write-Host ""
Write-Host "  Pour annuler : une touche, Ctrl+C, fermer cette fenetre," -ForegroundColor Yellow
Write-Host "  ou combo manette L1+L2+R1+R2 + Droite" -ForegroundColor Yellow
Write-Host ""

$cancelled = $false
$reason = ''
$end = (Get-Date).AddSeconds($delay)
while ((Get-Date) -lt $end) {
    $left = [Math]::Ceiling(($end - (Get-Date)).TotalSeconds)
    Write-Host -NoNewline ("`r  Extinction dans {0,2} s  " -f $left)
    try {
        if ([Console]::KeyAvailable) {
            $k = [Console]::ReadKey($true)
            $cancelled = $true
            $reason = "touche pressee: $($k.Key) (modifiers: $($k.Modifiers))"
            break
        }
    } catch {} # pas de console interactive (ex: test automatisé) : touches ignorées
    if ($cancelEvt.WaitOne(0)) { $cancelled = $true; $reason = 'event DS5Dongle_CancelShutdown signale'; break }
    Start-Sleep -Milliseconds 200
}
$cancelEvt.Dispose()

Write-Host ""
if ($cancelled) {
    "$(Get-Date -Format 'HH:mm:ss.fff') annule -> $reason" | Out-File $log -Append -Encoding utf8
    Write-Host ""
    Write-Host "  Extinction annulee." -ForegroundColor Green
    Start-Sleep -Seconds 2
    exit 0
}
"$(Get-Date -Format 'HH:mm:ss.fff') decompte termine -> extinction" | Out-File $log -Append -Encoding utf8

Write-Host ""
if ($Test) {
    Write-Host "  [TEST] shutdown /s /t 0 aurait ete lance ici." -ForegroundColor Cyan
    Start-Sleep -Seconds 3
} else {
    Write-Host "  Extinction..." -ForegroundColor Red
    & "$env:SystemRoot\System32\shutdown.exe" /s /t 0
}
