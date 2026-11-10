# Overlay "antisèche" des combos manette L1+L2+R1+R2 + croix directionnelle.
#
# Le firmware envoie Ctrl+Alt+Shift+O quand les 4 gâchettes sont tenues seules
# 300 ms, puis Ctrl+Alt+Shift+H au relâchement.
#
# Ce script est un processus résident (lancé à l'ouverture de session par
# tools/install-overlay-shortcuts.ps1) : il enregistre lui-même les deux
# raccourcis globaux et garde la fenêtre déjà construite, donc l'affichage est
# immédiat. L'ancienne version était relancée à chaque appui par un raccourci
# .lnk du menu Démarrer : l'Explorateur met ~3 s à déclencher ces raccourcis,
# auxquelles s'ajoutait le démarrage de PowerShell et de WPF.
#
#   (sans argument) -> démarre le processus résident (une seule instance)
#   -Stop           -> arrête l'instance en cours
param([switch]$Stop, [int]$Timeout = 15)

if ($Stop) {
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*combo-overlay.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    exit 0
}

# Libellés affichés (à adapter aux profils Display Magician réels).
$labels = @{
    Up    = 'Gaming profile'
    Left  = 'Desktop profile'
    Down  = 'Éteindre le PC'
    Right = 'Annuler extinction'
}

# Une seule instance à la fois.
$mutex = New-Object System.Threading.Mutex($false, 'DS5Dongle_ComboOverlay')
try { if (-not $mutex.WaitOne(0)) { exit 0 } } catch [System.Threading.AbandonedMutexException] { }

Add-Type -Namespace DS5 -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mods, uint vk);
[DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int index);
[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int index, int value);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hWnd, uint flags);
[DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr monitor, ref MONITORINFO info);
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int Size; public RECT Monitor, Work; public uint Flags; }
'@

# DPI "Per-Monitor V2" (Windows 10 1703+), à fixer avant le chargement de WPF :
# sans cela le processus est en DPI système et, sur un écran dont l'échelle
# diffère de celle de l'écran principal, Windows étire l'image (overlay flou et
# mal dimensionné). -4 = DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2.
[DS5.Native]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
[AppContext]::SetSwitch('Switch.System.Windows.DoNotScaleForDpiChanges', $false)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ShowActivated="False" Focusable="False"
        IsHitTestVisible="False" ResizeMode="NoResize" SizeToContent="WidthAndHeight"
        WindowStartupLocation="Manual" Left="-32000" Top="-32000">
  <Border CornerRadius="18" Background="#F2181A20" BorderBrush="#55FFFFFF" BorderThickness="1" Padding="22">
    <Grid>
      <Grid.Resources>
        <Style TargetType="Border" x:Key="Cell">
          <Setter Property="CornerRadius" Value="10"/>
          <Setter Property="Background" Value="#33FFFFFF"/>
          <Setter Property="Padding" Value="14,8"/>
          <Setter Property="Margin" Value="6"/>
          <Setter Property="MinWidth" Value="170"/>
        </Style>
        <Style TargetType="TextBlock">
          <Setter Property="Foreground" Value="White"/>
          <Setter Property="FontFamily" Value="Segoe UI"/>
          <Setter Property="FontSize" Value="17"/>
          <Setter Property="TextAlignment" Value="Center"/>
          <Setter Property="HorizontalAlignment" Value="Center"/>
        </Style>
      </Grid.Resources>
      <Grid.RowDefinitions><RowDefinition/><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
      <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>

      <Border Grid.Row="0" Grid.Column="1" Style="{StaticResource Cell}">
        <StackPanel><TextBlock Text="&#x25B2;" FontSize="22"/><TextBlock Name="Up"/></StackPanel></Border>
      <Border Grid.Row="1" Grid.Column="0" Style="{StaticResource Cell}">
        <StackPanel><TextBlock Text="&#x25C0;" FontSize="22"/><TextBlock Name="Left"/></StackPanel></Border>
      <StackPanel Grid.Row="1" Grid.Column="1" VerticalAlignment="Center" Margin="10">
        <TextBlock Text="L1 + L2 + R1 + R2" FontWeight="SemiBold"/>
        <TextBlock Text="+ croix directionnelle" FontSize="13" Opacity="0.7"/>
      </StackPanel>
      <Border Grid.Row="1" Grid.Column="2" Style="{StaticResource Cell}">
        <StackPanel><TextBlock Text="&#x25B6;" FontSize="22"/><TextBlock Name="Right"/></StackPanel></Border>
      <Border Grid.Row="2" Grid.Column="1" Style="{StaticResource Cell}">
        <StackPanel><TextBlock Text="&#x25BC;" FontSize="22"/><TextBlock Name="Down"/></StackPanel></Border>
    </Grid>
  </Border>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
foreach ($k in $labels.Keys) { $window.FindName($k).Text = $labels[$k] }

$hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $window).EnsureHandle()

# Jamais de focus, clics traversants, absent de Alt+Tab : l'overlay ne doit rien
# prendre au jeu. GWL_EXSTYLE = -20 ; NOACTIVATE | TOOLWINDOW | TRANSPARENT.
$exStyle = [DS5.Native]::GetWindowLong($hwnd, -20)
[DS5.Native]::SetWindowLong($hwnd, -20, $exStyle -bor 0x08000000 -bor 0x80 -bor 0x20) | Out-Null

$HWND_TOPMOST = [IntPtr](-1)
$SWP_NOSIZE = 0x1; $SWP_NOMOVE = 0x2; $SWP_NOACTIVATE = 0x10

# Un jeu en plein écran est souvent lui-même "topmost" et se remet au premier
# plan : tant que l'overlay est visible on le repasse en tête de la pile.
$raise = New-Object System.Windows.Threading.DispatcherTimer
$raise.Interval = [TimeSpan]::FromMilliseconds(100)
$raise.Add_Tick({
    if ([DateTime]::UtcNow -ge $script:deadline) { Hide-Overlay; return }
    [DS5.Native]::SetWindowPos($hwnd, $HWND_TOPMOST, 0, 0, 0, 0,
        $SWP_NOSIZE -bor $SWP_NOMOVE -bor $SWP_NOACTIVATE) | Out-Null
})

# Centre l'overlay sur l'écran de la fenêtre active (celui du jeu), pas sur
# celui de la souris. MONITOR_DEFAULTTOPRIMARY = 1.
function Move-OverlayToActiveScreen {
    $info = New-Object DS5.Native+MONITORINFO
    $info.Size = [Runtime.InteropServices.Marshal]::SizeOf($info)
    $monitor = [DS5.Native]::MonitorFromWindow([DS5.Native]::GetForegroundWindow(), 1)
    $rect = New-Object DS5.Native+RECT
    if ([DS5.Native]::GetMonitorInfo($monitor, [ref]$info) -and [DS5.Native]::GetWindowRect($hwnd, [ref]$rect)) {
        $w = $rect.Right - $rect.Left; $h = $rect.Bottom - $rect.Top
        $m = $info.Monitor
        $x = $m.Left + [int](($m.Right - $m.Left - $w) / 2)
        $y = $m.Top + [int](($m.Bottom - $m.Top - $h) / 2)
        [DS5.Native]::SetWindowPos($hwnd, $HWND_TOPMOST, $x, $y, 0, 0, $SWP_NOSIZE -bor $SWP_NOACTIVATE) | Out-Null
    }
}

function Show-Overlay {
    $script:deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
    if (-not $window.IsVisible) { $window.Opacity = 0; $window.Show() }
    Move-OverlayToActiveScreen
    # En arrivant sur un écran d'échelle différente, WPF redimensionne la
    # fenêtre : on recentre une fois la mise en page refaite, puis on révèle.
    $window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::ContextIdle, [Action] {
        Move-OverlayToActiveScreen
        $window.Opacity = 1
    }) | Out-Null
    $raise.Start()
}

function Hide-Overlay {
    $raise.Stop()
    $window.Hide()
}

# Raccourcis globaux Ctrl+Alt+Shift+O / H. MOD_ALT|MOD_CONTROL|MOD_SHIFT|MOD_NOREPEAT.
$HOTKEY_SHOW = 1; $HOTKEY_HIDE = 2
$hotkeys = @{ $HOTKEY_SHOW = 0x4F; $HOTKEY_HIDE = 0x48 }
$registered = @{}
function Register-Hotkeys {
    foreach ($id in $hotkeys.Keys) {
        if (-not $registered[$id]) {
            $registered[$id] = [DS5.Native]::RegisterHotKey($hwnd, $id, 0x4007, $hotkeys[$id])
        }
    }
    return -not ($registered.Values -contains $false)
}
# Si un autre programme tient encore un des raccourcis (anciens .lnk du menu
# Démarrer pas encore relâchés par l'Explorateur), on réessaie jusqu'à l'obtenir.
if (-not (Register-Hotkeys)) {
    $retry = New-Object System.Windows.Threading.DispatcherTimer
    $retry.Interval = [TimeSpan]::FromSeconds(2)
    $retry.Add_Tick({ if (Register-Hotkeys) { $retry.Stop() } })
    $retry.Start()
}

$source = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
$source.AddHook({
    param($h, $msg, $wParam, $lParam, $handled)
    if ($msg -eq 0x0312) {   # WM_HOTKEY
        switch ($wParam.ToInt32()) {
            $HOTKEY_SHOW { Show-Overlay }
            $HOTKEY_HIDE { Hide-Overlay }
        }
    }
    return [IntPtr]::Zero
})

# Premier rendu fait d'avance (invisible, hors écran) pour que le premier appui
# soit aussi rapide que les suivants.
$window.Opacity = 0
$window.Show()
$window.Dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
$window.Hide()

[System.Windows.Threading.Dispatcher]::Run()
