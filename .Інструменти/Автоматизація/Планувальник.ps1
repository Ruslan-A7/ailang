# Автор: Ruslan_A7 (RA7). Розробник: Ruslan_A7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.3.0.
param()
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Сховище.psm1') -Force
$projectRoot = Get-AILangRoot
$rootHash = [Security.Cryptography.SHA256]::Create()
try { $identity = [BitConverter]::ToString($rootHash.ComputeHash([Text.Encoding]::UTF8.GetBytes($projectRoot.ToLowerInvariant()))).Replace('-','') }
finally { $rootHash.Dispose() }
$instance = [Threading.Mutex]::new($false,('Local\AILangTimer' + $identity))
$ownsMutex = $false
$script:job = $null
$script:jobKind = ''
$script:due = $null
$script:armed = $false
$script:editedAt = $null
try {
    try { $ownsMutex = $instance.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (!$ownsMutex) { return }
    Add-Type -AssemblyName PresentationFramework
    [xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="AILang · планувальник v0.3.0" Width="680" Height="760" MinWidth="600" MinHeight="690" Background="#101C2B" Foreground="#E5EDF8" WindowStartupLocation="CenterScreen">
 <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel Margin="22">
  <TextBlock Text="AILang · відкладене продовження" FontSize="23" Margin="0,0,0,8"/>
  <TextBlock Text="Доставка через Codex queue в наявний чат. Закриття вікна скасовує очікування, але не вже переданий запит." TextWrapping="Wrap" Margin="0,0,0,14"/>
  <TextBlock Text="UUID сеансу Codex (зі /status цільового чату)"/>
  <TextBox Name="Session" Margin="0,5,0,12" Padding="8"/>
  <TextBlock Text="Запит на продовження (не вводьте секрети)"/>
  <TextBox Name="Prompt" AcceptsReturn="True" TextWrapping="Wrap" Height="110" Padding="8" Margin="0,5,0,10"/>
  <TextBlock Text="Історія: чернетки, спроби та прийняті queue запити"/>
  <ComboBox Name="History" Margin="0,5,0,10" Padding="6" DisplayMemberPath="label"/>
  <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
   <TextBlock Text="Хвилини: " VerticalAlignment="Center"/>
   <TextBox Name="Minutes" Text="60" Width="80" Padding="5"/>
   <Button Name="Start" Content="Запустити таймер" Padding="12,6" Margin="10,0,0,0"/>
   <Button Name="Stop" Content="Зупинити" Padding="12,6" Margin="10,0,0,0"/>
  </StackPanel>
  <CheckBox Name="Automatic" Content="Дозволити автоматичне надсилання в указаний сеанс" Foreground="#E5EDF8" Margin="0,0,0,10"/>
  <CheckBox Name="Repeat" Content="Повторювати через задані хвилини після прийняття queue (не завершення роботи)" Foreground="#E5EDF8" Margin="0,0,0,12"/>
  <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
   <Button Name="Limits" Content="Перевірити квоти" Padding="12,6"/>
   <Button Name="Reset" Content="Таймер до відновлення" Padding="12,6" Margin="10,0,0,0"/>
  </StackPanel>
  <TextBlock Name="Countdown" Text="—" FontSize="40" Foreground="#7BE0CE"/>
  <TextBlock Name="Quota" Text="Квоти ще не перевірялися" TextWrapping="Wrap" Margin="0,8,0,8"/>
  <TextBlock Name="Status" Text="Автоматичне надсилання вимкнене" TextWrapping="Wrap" Margin="0,0,0,12"/>
  <TextBlock Text="Таймер не підтверджує відновлення квот. Перед надсиланням читаються фактичні квоти. Помилка зупиняє автоматику без повтору. Історія зберігається тільки локально у .Стан." TextWrapping="Wrap" Foreground="#B6C6DB"/>
  <TextBlock Text="Автор: Ruslan_A7 (RA7) · Codex (GPT-6), OpenAI · Створено з використанням AILang · RA7 Open Free License" TextWrapping="Wrap" FontSize="11" Margin="0,12,0,0"/>
 </StackPanel></ScrollViewer>
</Window>
'@
    $window = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($markup))
    $controls = @{}
    foreach ($name in @('Session','Prompt','History','Minutes','Start','Stop','Automatic','Repeat','Limits','Reset','Countdown','Quota','Status')) { $controls[$name] = $window.FindName($name) }
    $controls.Prompt.Text = 'Перечитай AGENTS.md, поточні налаштування та план. Перевір доступні ліміти. Продовжуй погоджену роботу з місця зупинки; зберігай результат і місце продовження. Не запускай тести без дозволу.'
    $settingsPaths = @('.Налаштування/Розробка/Проєкт.md','.Налаштування/Результат/Продукт.md','.Налаштування/Ліміти.md','.Налаштування/Дозволи.md')
    function Get-SettingsFingerprint {
        return (($settingsPaths | ForEach-Object {
            $path = Join-Path $projectRoot $_
            if (Test-Path -LiteralPath $path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash } else { 'missing' }
        }) -join ':')
    }
    $settingsFingerprint = Get-SettingsFingerprint
    function Refresh-History {
        $controls.History.Items.Clear()
        foreach ($entry in @(Read-AILangHistory | Sort-Object utc -Descending)) {
            $preview = ([string]$entry.prompt).Replace("`r",' ').Replace("`n",' ')
            if ($preview.Length -gt 65) { $preview = $preview.Substring(0,65) + '…' }
            $null = $controls.History.Items.Add([pscustomobject]@{label=($entry.utc + ' · ' + $entry.kind + ' · ' + $preview);entry=$entry})
        }
    }
    function Stop-Automation([string]$message) {
        $script:due = $null
        $script:armed = $false
        $controls.Automatic.IsChecked = $false
        $controls.Status.Text = $message
    }
    function Save-Draft {
        if (![string]::IsNullOrWhiteSpace($controls.Prompt.Text)) {
            Add-AILangHistory 'чернетка' $controls.Prompt.Text $controls.Session.Text
            Refresh-History
        }
        $script:editedAt = $null
    }
    function Read-Inputs {
        $id = [guid]::Empty
        if (![guid]::TryParse($controls.Session.Text.Trim(),[ref]$id) -or $id -eq [guid]::Empty) { throw 'Укажіть дійсний UUID цільового сеансу зі /status' }
        $minutes = 0
        if (![int]::TryParse($controls.Minutes.Text,[ref]$minutes) -or $minutes -lt 1 -or $minutes -gt 10080) { throw 'Час має бути цілим числом від 1 до 10080 хвилин' }
        if ([string]::IsNullOrWhiteSpace($controls.Prompt.Text)) { throw 'Запит не може бути порожнім' }
        if ($controls.Prompt.Text.Length -gt 24000) { throw 'Скоротіть запит до 24000 символів для доставки queue' }
        return [pscustomobject]@{session=$id.ToString();minutes=$minutes;prompt=$controls.Prompt.Text}
    }
    function Start-QuotaJob([string]$purpose) {
        if ($script:job) { throw 'Попередня операція ще виконується' }
        $script:jobKind = $purpose
        $script:job = Start-Job -ScriptBlock { param($adapter,$root) Set-Location -LiteralPath $root; & $adapter } -ArgumentList (Join-Path $PSScriptRoot 'Адаптери/Ліміти-Codex.ps1'),$projectRoot
        $controls.Status.Text = 'Читання квот…'
    }
    $controls.History.Add_SelectionChanged({
        if ($controls.History.SelectedItem) {
            $entry = $controls.History.SelectedItem.entry
            $controls.Prompt.Text = $entry.prompt
            $controls.Session.Text = $entry.session
        }
    })
    $controls.Prompt.Add_TextChanged({ $script:editedAt = [DateTime]::UtcNow })
    $controls.Session.Add_TextChanged({ $script:editedAt = [DateTime]::UtcNow })
    $controls.Start.Add_Click({
        try {
            if ($script:job) { throw 'Дочекайтеся завершення поточної операції' }
            $script:inputs = Read-Inputs
            Save-Draft
            $script:due = [DateTime]::UtcNow.AddMinutes($script:inputs.minutes)
            $script:armed = $true
            $controls.Status.Text = 'Таймер запущено; надсилання можливе лише з увімкненою автоматикою'
        } catch { $controls.Status.Text = $_.Exception.Message }
    })
    $controls.Stop.Add_Click({ Stop-Automation 'Очікування зупинено. Уже надісланий запит не скасовується.' })
    $controls.Automatic.Add_Unchecked({
        # Не скасовуємо вже прийнятий запит і не вдаємо, що його відкликано.
        if (!$script:job -or $script:jobKind -ne 'send') { $controls.Status.Text = 'Надсилання вимкнене; таймер може працювати як нагадування' }
    })
    $controls.Limits.Add_Click({ try { Start-QuotaJob 'display' } catch { $controls.Status.Text = $_.Exception.Message } })
    $controls.Reset.Add_Click({
        try { $script:inputs = Read-Inputs; Save-Draft; Start-QuotaJob 'reset' }
        catch { $controls.Status.Text = $_.Exception.Message }
    })
    function Update-Timer {
        if ($script:editedAt -and ([DateTime]::UtcNow - $script:editedAt).TotalSeconds -ge 2) { Save-Draft }
        if ($script:armed -and (Get-SettingsFingerprint) -ne $settingsFingerprint) {
            Stop-Automation 'Налаштування змінено. Перегляньте вплив і знову відкрийте планувальник.'
        }
        if ($script:job -and $script:job.State -in @('Completed','Failed','Stopped')) {
            $finishedKind = $script:jobKind
            $failed = $script:job.State -ne 'Completed'
            $data = @(Receive-Job -Job $script:job -ErrorAction SilentlyContinue)
            Remove-Job -Job $script:job
            $script:job = $null
            if ($failed) { Stop-Automation 'Операція завершилася помилкою. Перевірте стан сеансу; автоматичного повтору немає.'; return }
            if ($finishedKind -eq 'send') {
                Add-AILangHistory 'прийнято queue' $script:inputs.prompt $script:inputs.session
                Refresh-History
                $controls.Status.Text = 'Queue прийняла запит. Це не підтвердження завершення роботи агента.'
                if ($controls.Repeat.IsChecked -and $controls.Automatic.IsChecked -and $script:armed) {
                    $script:due = [DateTime]::UtcNow.AddMinutes($script:inputs.minutes)
                } else { $script:due = $null; $script:armed = $false }
                return
            }
            $quota = $data | Select-Object -Last 1
            if (!$quota -or $quota.status -ne 'known') {
                $controls.Quota.Text = 'Квоти невідомі: перевірте CLI/авторизацію/мережу'
                Stop-Automation 'Без достовірних квот автоматичне надсилання зупинено'
                return
            }
            $controls.Quota.Text = (@($quota.windows | ForEach-Object { '{0} хв: залишок {1}%, відновлення UTC {2}' -f $_.minutes,$_.remaining,$_.resetUtc }) -join "`n")
            $short = @($quota.windows | Where-Object minutes -eq 300)
            $week = @($quota.windows | Where-Object minutes -eq 10080)
            $blocked = @($quota.windows | Where-Object { ($_.minutes -eq 300 -and $_.remaining -le 10) -or ($_.minutes -eq 10080 -and $_.remaining -le 5) -or $_.remaining -le 0 })
            if ($finishedKind -eq 'display') { $controls.Status.Text = 'Квоти прочитано; запит не надсилався'; return }
            if (!$short.Count -or !$week.Count) { Stop-Automation 'Набір вікон квот не відповідає налаштованій політиці 5 годин / тиждень. Потрібна адаптація.'; return }
            if ($finishedKind -eq 'reset' -or $blocked.Count) {
                $resets = @($blocked | Where-Object resetUtc | ForEach-Object { [DateTime]::Parse($_.resetUtc).ToUniversalTime() })
                if ($blocked.Count -and $resets.Count -eq $blocked.Count) {
                    $script:due = ($resets | Sort-Object -Descending | Select-Object -First 1).AddMinutes(1)
                    if ($script:due -le [DateTime]::UtcNow) { Stop-Automation 'Відновлення не підтверджено після очікуваного часу'; return }
                    $script:armed = $true
                    $controls.Status.Text = 'Очікування останнього обмежувального вікна + 1 хв; потім нова перевірка'
                } elseif ($blocked.Count) { Stop-Automation 'Час відновлення невідомий' }
                else { $controls.Status.Text = 'Квоти дозволяють роботу; запустіть таймер на потрібний час' }
                return
            }
            if (!$script:armed -or !$controls.Automatic.IsChecked) { $controls.Status.Text = 'Надсилання вимкнене'; return }
            if ((Get-SettingsFingerprint) -ne $settingsFingerprint) { Stop-Automation 'Конфігурація змінилася; потрібен повторний перегляд'; return }
            Add-AILangHistory 'спроба надсилання' $script:inputs.prompt $script:inputs.session
            Refresh-History
            $script:jobKind = 'send'
            $script:job = Start-Job -ScriptBlock {
                param($adapter,$root,$session,$prompt)
                & $adapter -SessionId $session -Prompt $prompt -ProjectRoot $root
            } -ArgumentList (Join-Path $PSScriptRoot 'Адаптери/Надіслати-Codex.ps1'),$projectRoot,$script:inputs.session,$script:inputs.prompt
            $controls.Status.Text = 'Доставка в наявний чат через queue; очікування підтвердження прийняття'
        }
        if ($script:due) {
            $left = [Math]::Max(0,($script:due - [DateTime]::UtcNow).TotalSeconds)
            $span = [TimeSpan]::FromSeconds([Math]::Ceiling($left))
            $controls.Countdown.Text = '{0:00}:{1:00}:{2:00}' -f [int][Math]::Floor($span.TotalHours),$span.Minutes,$span.Seconds
            if ($left -le 0 -and !$script:job) {
                $script:due = $null
                if ($controls.Automatic.IsChecked -and $script:armed) { $script:inputs = Read-Inputs; Save-Draft; Start-QuotaJob 'before-send' }
                else { $script:armed = $false; $controls.Status.Text = 'Час настав. Автоматичне надсилання вимкнене.' }
            }
        } elseif (!$script:job) { $controls.Countdown.Text = '—' }
    }
    Refresh-History
    $timer = [Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({ try { Update-Timer } catch { Stop-Automation 'Помилка локального стану або параметрів; очікування зупинено' } })
    $window.Add_Closing({
        if ($script:job -and $script:jobKind -eq 'send') {
            $_.Cancel = $true
            $controls.Status.Text = 'Queue ще передає запит. Вимкніть повтор і дочекайтеся підтвердження перед закриттям.'
        }
    })
    $window.Add_Closed({ $timer.Stop() })
    $timer.Start()
    $null = $window.ShowDialog()
} catch {
    if ('System.Windows.MessageBox' -as [type]) { $null = [Windows.MessageBox]::Show('Не вдалося відкрити планувальник. Перевірте PowerShell/WPF та локальну історію.','AILang') }
    else { Write-Error 'Не вдалося завантажити PowerShell/WPF' }
} finally {
    if ($script:job) { Stop-Job -Job $script:job; Remove-Job -Job $script:job }
    if ($ownsMutex) { $instance.ReleaseMutex() }
    $instance.Dispose()
}
