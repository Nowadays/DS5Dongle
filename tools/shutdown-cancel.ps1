# Déclenché par le combo manette L1+L2+R1+R2 + Droite (Ctrl+Alt+Shift+A via le
# .lnk "Annuler extinction (manette)" du menu Démarrer).
# Annule une éventuelle extinction système et signale à shutdown-prompt.ps1
# d'arrêter son décompte (événement nommé partagé).
& "$env:SystemRoot\System32\shutdown.exe" /a 2>$null
$evt = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::ManualReset, 'DS5Dongle_CancelShutdown')
$evt.Set() | Out-Null
$evt.Dispose()
