# Installe l'overlay des combos (tools/combo-overlay.ps1) comme processus
# résident : un raccourci dans le dossier Démarrage le lance à chaque ouverture
# de session, et il écoute lui-même Ctrl+Alt+Shift+O (afficher) / +H (masquer).
#
# Supprime aussi les anciens raccourcis à touche du menu Démarrer : ils
# retiendraient ces deux combinaisons et l'Explorateur met ~3 s à les déclencher.
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$vbs = Join-Path $PSScriptRoot 'run-hidden.vbs'
$overlay = Join-Path $PSScriptRoot 'combo-overlay.ps1'
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'

foreach ($old in 'Overlay combos manette.lnk', 'Masquer overlay combos.lnk') {
    $path = Join-Path $startMenu $old
    if (Test-Path $path) { Remove-Item $path; Write-Host "Supprimé  $old" }
}

$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startMenu 'Startup\Overlay combos manette.lnk'))
$lnk.TargetPath = $wscript
$lnk.Arguments = "`"$vbs`" `"$overlay`""
$lnk.WorkingDirectory = $PSScriptRoot
$lnk.Save()
Write-Host "OK  démarrage automatique  ->  $($lnk.FullName)"

# (Re)lance l'overlay tout de suite, sans attendre la prochaine session.
& $overlay -Stop
& $wscript $vbs $overlay
Write-Host 'OK  overlay lancé (Ctrl+Alt+Shift+O / H)'
