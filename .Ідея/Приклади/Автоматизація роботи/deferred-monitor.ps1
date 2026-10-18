param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'automation-common.ps1')
$context = Get-AutomationContext
$projectRoot = $context.ProjectRoot
$stateRoot = $context.StateRoot
New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
$instance = [Threading.Mutex]::new($false,($context.MutexPrefix+'Monitor'))
if (!$instance.WaitOne(0)) { $instance.Dispose(); return }
try {
    @{pid=$PID;state='starting'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'monitor.json') -Encoding UTF8
    Add-Type -AssemblyName PresentationFramework
    [xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="ScrapHunterMan — відкладені запити" Width="490" Height="440" MinWidth="440" MinHeight="420" Background="#111F2B" Foreground="#E3EEF2" WindowStartupLocation="CenterScreen">
  <StackPanel Margin="20">
    <TextBlock Text="Відкладене продовження" FontSize="22" Margin="0,0,0,15"/>
    <Border Background="#1C3040" CornerRadius="8" Padding="12" Margin="0,0,0,10"><StackPanel>
      <TextBlock Text="Перший запит" FontSize="15"/>
      <TextBlock Name="FirstTimer" FontSize="30" FontWeight="Bold" Foreground="#8AE2D2"/>
      <TextBlock Name="FirstStatus" TextWrapping="Wrap"/>
    </StackPanel></Border>
    <Border Background="#1C3040" CornerRadius="8" Padding="12" Margin="0,0,0,12"><StackPanel>
      <TextBlock Name="CycleTitle" Text="Циклічний запит" FontSize="15"/>
      <TextBlock Name="CycleTimer" FontSize="24" FontWeight="Bold" Foreground="#8AE2D2"/>
      <TextBlock Name="CycleStatus" TextWrapping="Wrap"/>
    </StackPanel></Border>
    <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
      <Button Name="Pause" Content="Призупинити" Padding="12,6" Margin="0,0,8,0" Foreground="#10222C"/>
      <Button Name="Stop" Content="Зупинити таймери" Padding="12,6" Foreground="#10222C"/>
    </StackPanel>
    <TextBlock Text="Закриття цього вікна не зупиняє таймерів. Таймер надсилає запит, але не підтверджує оновлення лімітів." FontSize="12" Foreground="#A7BBC7" TextWrapping="Wrap"/>
  </StackPanel>
</Window>
'@
    $window = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($markup))
    $window.Title = $context.Settings.DisplayName + ' — відкладені запити'
    $window.FindName('CycleTitle').Text = 'Циклічний запит · інтервал ' + [TimeSpan]::FromSeconds([int]$context.Settings.CycleDelaySeconds).ToString()
    $window.ShowInTaskbar = $true
    $window.ShowActivated = $true
    $window.Add_ContentRendered({
        $window.WindowState = 'Normal'
        $window.Topmost = $true
        $window.Activate() | Out-Null
        @{pid=$PID;state='visible'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'monitor.json') -Encoding UTF8
    })
    $firstTimer = $window.FindName('FirstTimer'); $firstStatus = $window.FindName('FirstStatus')
    $cycleTimer = $window.FindName('CycleTimer'); $cycleStatus = $window.FindName('CycleStatus')
    $pauseButton = $window.FindName('Pause'); $stopButton = $window.FindName('Stop')
    $pausePath = Join-Path $stateRoot 'pause'
    $stopPath = Join-Path $stateRoot 'stop'
    $pauseButton.Add_Click({
        if (Test-Path -LiteralPath $pausePath) { Remove-Item -LiteralPath $pausePath -Force }
        else { New-Item -ItemType File -Path $pausePath -Force | Out-Null }
    })
    $stopButton.Add_Click({ New-Item -ItemType File -Path $stopPath -Force | Out-Null })
    function Show-Timer([string]$mode, $countdown, $label) {
        $path = Join-Path $stateRoot ($mode+'.json')
        $countdown.Text = '—'
        if (!(Test-Path -LiteralPath $path)) { $label.Text = 'Не запущено'; return }
        try { $state = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { return }
        if ($mode -eq 'cycle' -and $state.interval_seconds) {
            $window.FindName('CycleTitle').Text = 'Циклічний запит · інтервал ' + [TimeSpan]::FromSeconds([int]$state.interval_seconds).ToString()
        }
        $captions = @{ waiting='Очікування'; paused='Пауза'; sending='Передавання запиту'; queued='Запит передано'; cancelled='Зупинено'; failed='Помилка передавання — автоматичний повтор вимкнений' }
        $label.Text = if ($captions.ContainsKey([string]$state.state)) { $captions[[string]$state.state] } else { 'Стан невідомий' }
        if ($state.state -in @('waiting','paused','sending')) {
            $worker = if ($state.pid) { Get-Process -Id $state.pid -ErrorAction SilentlyContinue } else { $null }
            if (!$worker -or $worker.ProcessName -ne 'powershell') { $label.Text='Процес таймера не працює'; return }
            if (Test-Path -LiteralPath $stopPath) { $label.Text='Зупинення…'; return }
            $seconds = if ($state.state -eq 'paused') { [double]$state.remaining_seconds } else { [Math]::Max(0,([DateTimeOffset]::Parse($state.due_utc)-[DateTimeOffset]::UtcNow).TotalSeconds) }
            $duration = [TimeSpan]::FromSeconds([Math]::Ceiling($seconds))
            $countdown.Text = '{0:00}:{1:00}:{2:00}' -f [int][Math]::Floor($duration.TotalHours),$duration.Minutes,$duration.Seconds
            if ($state.state -eq 'waiting') { $label.Text += ' · запит о '+[DateTimeOffset]::Parse($state.due_utc).ToLocalTime().ToString('HH:mm:ss') }
        }
    }
    $refresh = {
        $window.Topmost = $false
        Show-Timer 'first' $firstTimer $firstStatus
        Show-Timer 'cycle' $cycleTimer $cycleStatus
        $pauseButton.Content = if (Test-Path -LiteralPath $pausePath) { 'Продовжити' } else { 'Призупинити' }
        $pauseButton.IsEnabled = !(Test-Path -LiteralPath $stopPath)
    }
    $timer = [Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick($refresh)
    & $refresh
    $timer.Start()
    $window.Add_Closed({ $timer.Stop(); @{state='closed'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'monitor.json') -Encoding UTF8 })
    $window.ShowDialog() | Out-Null
} catch {
    @{state='failed';error=$_.Exception.Message} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateRoot 'monitor.json') -Encoding UTF8
    throw
} finally {
    $instance.ReleaseMutex()
    $instance.Dispose()
}
