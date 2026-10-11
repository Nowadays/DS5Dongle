# Crée les raccourcis du menu Démarrer qui relient les touches envoyées par le
# dongle à tools/combo-overlay.ps1 :
#   Ctrl+Alt+Shift+O -> afficher l'overlay des combos
#   Ctrl+Alt+Shift+H -> le masquer
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$vbs = Join-Path $PSScriptRoot 'run-hidden.vbs'
$overlay = Join-Path $PSScriptRoot 'combo-overlay.ps1'
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'
$shell = New-Object -ComObject WScript.Shell

foreach ($s in @(
    @{ Name = 'Overlay combos manette'; Hotkey = 'Ctrl+Alt+Shift+O'; Args = '' },
    @{ Name = 'Masquer overlay combos'; Hotkey = 'Ctrl+Alt+Shift+H'; Args = ' -Hide' }
)) {
    $lnk = $shell.CreateShortcut((Join-Path $startMenu "$($s.Name).lnk"))
    $lnk.TargetPath = $wscript
    $lnk.Arguments = "`"$vbs`" `"$overlay`"$($s.Args)"
    $lnk.WorkingDirectory = $PSScriptRoot
    $lnk.Hotkey = $s.Hotkey
    $lnk.Save()
    Write-Host "OK  $($s.Hotkey)  ->  $($s.Name)"
}
