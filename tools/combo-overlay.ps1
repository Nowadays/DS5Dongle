# Overlay "antisèche" des combos manette L1+L2+R1+R2 + croix directionnelle.
#
# Le firmware envoie Ctrl+Alt+Shift+O quand les 4 gâchettes sont tenues seules
# 300 ms, puis Ctrl+Alt+Shift+H au relâchement. Les raccourcis du menu Démarrer
# (tools/install-overlay-shortcuts.ps1) lancent ce script via run-hidden.vbs :
#   (sans argument) -> affiche l'overlay
#   -Hide           -> le masque
#
# Le masquage passe par un fichier horodaté plutôt qu'un événement nommé : si
# l'appui est très court, -Hide peut tourner avant que l'overlay soit prêt, et
# un événement sans handle ouvert serait perdu. L'overlay se ferme dès que le
# fichier est plus récent que son propre démarrage (ou après $Timeout s).
param([switch]$Hide, [int]$Timeout = 15)

$hideFile = Join-Path $env:TEMP 'ds5dongle-overlay.hide'

if ($Hide) {
    [IO.File]::WriteAllText($hideFile, '')
    [IO.File]::SetLastWriteTimeUtc($hideFile, [DateTime]::UtcNow)
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
if (-not $mutex.WaitOne(0)) { exit 0 }

$started = (Get-Process -Id $PID).StartTime.ToUniversalTime()

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ShowActivated="False" Focusable="False"
        IsHitTestVisible="False" ResizeMode="NoResize" SizeToContent="WidthAndHeight"
        WindowStartupLocation="CenterScreen">
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

$deadline = [DateTime]::UtcNow.AddSeconds($Timeout)
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(50)
$timer.Add_Tick({
    $hidden = (Test-Path $hideFile) -and ([IO.File]::GetLastWriteTimeUtc($hideFile) -ge $started)
    if ($hidden -or [DateTime]::UtcNow -ge $deadline) { $window.Close() }
})
$timer.Start()

$window.ShowDialog() | Out-Null
$mutex.ReleaseMutex()
