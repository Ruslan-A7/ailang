# Автор: Ruslan_A7 (RA7). Розробник: Ruslan_A7 з Codex (GPT-6), OpenAI.
# Створено з використанням AILang. RA7 Open Free License: https://ra7.iuid.cc/LICENSE. Версія 0.6.6.
param()
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Сховище.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Схвалення.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Політика-запиту.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Сеанс.psm1') -Force
$projectRoot = Get-AILangRoot
$projectVersion = [IO.File]::ReadAllText((Join-Path $projectRoot 'VERSION'),[Text.Encoding]::UTF8).Trim()
if ($projectVersion -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') { throw 'Некоректна версія у VERSION: очікується X.Y.Z' }
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
$script:timerMode = 'manual'
$script:intervalMinutes = 60
$script:deliveryId = $null
$script:quotaCancelled = $false
try {
    try { $ownsMutex = $instance.WaitOne(0) } catch [Threading.AbandonedMutexException] { $ownsMutex = $true }
    if (!$ownsMutex) {
        Add-Type -AssemblyName PresentationFramework
        $null = [Windows.MessageBox]::Show('Планувальник цього проєкту вже відкритий. Перейдіть до його вікна на панелі завдань.','AILang')
        return
    }
    Add-Type -AssemblyName PresentationFramework
    [xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="AILang · планувальник" Width="740" Height="880" MinWidth="680" MinHeight="690" Background="#101C2B" Foreground="#E5EDF8" WindowStartupLocation="CenterScreen">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Foreground" Value="#10222C"/><Setter Property="MinHeight" Value="32"/></Style>
  <Style TargetType="TextBox"><Setter Property="Foreground" Value="#10222C"/></Style>
  <Style TargetType="ComboBox"><Setter Property="Foreground" Value="#10222C"/></Style>
 </Window.Resources>
 <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel Margin="22">
  <TextBlock Text="AILang · відкладене продовження" FontSize="23" Margin="0,0,0,8"/>
  <TextBlock Text="Доставка через Codex queue в наявний чат. Закриття вікна скасовує очікування, але не вже переданий запит." TextWrapping="Wrap" Margin="0,0,0,14"/>
  <TextBlock Text="UUID сеансу Codex (зі /status цільового чату)"/>
  <Grid Margin="0,5,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="3*"/><ColumnDefinition Width="2*"/></Grid.ColumnDefinitions>
   <TextBox Name="Session" Grid.Column="0" Padding="8"/>
   <TextBlock Name="ChatName" Grid.Column="1" Text="Назва чату ще не отримана" TextWrapping="Wrap" Margin="12,0,0,0" VerticalAlignment="Center"/>
  </Grid>
  <WrapPanel Margin="0,0,0,10">
   <Button Name="RefreshName" Content="Оновити назву чату" Padding="12,6"/>
   <Button Name="SelectCodex" Content="Codex.exe…" Padding="12,6" Margin="10,0,0,0" ToolTip="Оберіть встановлений codex.exe, якщо його немає в PATH. Шлях зберігається лише локально."/>
  </WrapPanel>
  <TextBlock Text="Запит на продовження (не вводьте секрети)"/>
  <TextBox Name="Prompt" AcceptsReturn="True" TextWrapping="Wrap" Height="110" Padding="8" Margin="0,5,0,10"/>
  <WrapPanel Margin="0,0,0,10">
   <Button Name="NewPrompt" Content="Новий запит" Padding="12,6"/>
   <Button Name="SavePrompt" Content="Зберегти запит" Padding="12,6" Margin="10,0,0,0"/>
   <Button Name="Journal" Content="Журнал схвалень" Padding="12,6" Margin="10,0,0,0"/>
   <Button Name="SendNow" Content="Надіслати зараз" Padding="12,6" Margin="10,0,0,0" ToolTip="Одноразова доставка з ручними схваленнями після перевірки квот. Поточний відлік буде скасовано."/>
  </WrapPanel>
  <TextBlock Text="Історія: чернетки, спроби та прийняті queue запити"/>
  <CheckBox Name="SentOnly" Content="Показувати лише надіслані запити" Foreground="#E5EDF8" Margin="0,5,0,3"/>
  <ComboBox Name="History" Margin="0,5,0,10" Padding="6" DisplayMemberPath="label"/>
  <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
   <TextBlock Text="Час ГГ:ХХ (або хв): " VerticalAlignment="Center"/>
   <TextBox Name="Minutes" Text="01:00" Width="80" Padding="5"/>
   <Button Name="Start" Content="Ручний таймер" Padding="12,6" Margin="10,0,0,0"/>
   <Button Name="Stop" Content="Зупинити" Padding="12,6" Margin="10,0,0,0"/>
  </StackPanel>
  <Button Name="AutoStart" Content="Увімкнути автоматичний цикл · 05:05" Padding="12,8" Margin="0,0,0,10"/>
  <CheckBox Name="Automatic" Content="Дозволити автоматичне надсилання в указаний сеанс" Foreground="#E5EDF8" Margin="0,0,0,10"/>
  <CheckBox Name="Present" Content="Я за ПК — дозволи схвалюю особисто (для наступного запиту)" IsChecked="True" Foreground="#E5EDF8" Margin="0,0,0,10"/>
  <TextBlock Name="ApprovalStatus" Text="Ручні схвалення. Режим поточного чату змінюється в його меню дозволів." TextWrapping="Wrap" Margin="0,0,0,10"/>
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
    $window.Title = 'AILang · планувальник v' + $projectVersion
    $controls = @{}
    foreach ($name in @('Session','Prompt','History','Minutes','Start','Stop','Automatic','Repeat','Limits','Reset','Countdown','Quota','Status','Present','ApprovalStatus','AutoStart','NewPrompt','SavePrompt','SentOnly','Journal','SendNow','ChatName','RefreshName','SelectCodex')) { $controls[$name] = $window.FindName($name) }
    $preferences=Read-AILangPreferences
    $script:codexExecutable=$preferences.codexExecutable
    $controls.Session.Text=$preferences.session
    $controls.ChatName.Tag=if ($preferences.name) {$preferences.session} else {''}
    if ($preferences.name) { $controls.ChatName.Text=$preferences.name }
    if (!$preferences.session) {
        $recent=Read-AILangHistory | Sort-Object utc -Descending | Where-Object { $_.session -match '^[a-fA-F0-9-]{36}$' } | Select-Object -First 1
        if ($recent) { $controls.Session.Text=$recent.session }
    }
    try { $script:codexExecutable=Resolve-AILangCodex } catch { $controls.Quota.Text='Оберіть встановлений codex.exe кнопкою вище' }
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
        $entries = @(Read-AILangHistory | Sort-Object utc -Descending)
        if ($controls.SentOnly.IsChecked) { $entries = @($entries | Where-Object kind -eq 'прийнято queue') }
        foreach ($entry in $entries) {
            $preview = ([string]$entry.prompt).Replace("`r",' ').Replace("`n",' ')
            if ($preview.Length -gt 65) { $preview = $preview.Substring(0,65) + '…' }
            $null = $controls.History.Items.Add([pscustomobject]@{label=($entry.utc + ' · ' + $entry.kind + ' · ' + $preview);entry=$entry})
        }
        $notice=Get-AILangHistoryNotice
        if ($notice) { $controls.Status.Text=$notice }
    }
    function Save-CurrentPreferences {
        $name=if ($controls.ChatName.Tag -eq $controls.Session.Text.Trim()) { $controls.ChatName.Text } else { '' }
        Save-AILangPreferences -Session $controls.Session.Text.Trim() -Name $name -CodexExecutable $script:codexExecutable
    }
    function Stop-Automation([string]$message) {
        $script:due = $null
        $script:armed = $false
        $script:quotaCancelled = $true
        $controls.Automatic.IsChecked = $false
        $controls.Status.Text = $message
    }
    function Save-Draft {
        Save-CurrentPreferences
        if (![string]::IsNullOrWhiteSpace($controls.Prompt.Text)) {
            Add-AILangHistory 'чернетка' $controls.Prompt.Text $controls.Session.Text
            Refresh-History
        }
        $script:editedAt = $null
    }
    function Read-Inputs {
        param([switch]$UseAutomaticInterval)
        $id = [guid]::Empty
        if (![guid]::TryParse($controls.Session.Text.Trim(),[ref]$id) -or $id -eq [guid]::Empty) { throw 'Укажіть дійсний UUID цільового сеансу зі /status' }
        $minutes = 0
        $timeText = $controls.Minutes.Text.Trim()
        if ($UseAutomaticInterval) { $minutes = 305 }
        elseif ($timeText -match '^(\d{1,3}):([0-5]\d)$') { $minutes = [int]$Matches[1]*60 + [int]$Matches[2] }
        elseif (![int]::TryParse($timeText,[ref]$minutes)) { throw 'Час: ГГ:ХХ (наприклад 01:30) або ціла кількість хвилин' }
        if ($minutes -lt 1 -or $minutes -gt 10080) { throw 'Час має бути від 1 хвилини до 7 днів' }
        if ([string]::IsNullOrWhiteSpace($controls.Prompt.Text)) { throw 'Запит не може бути порожнім' }
        if ($controls.Prompt.Text.Length -gt 24000) { throw 'Скоротіть запит до 24000 символів для доставки queue' }
        $mode = if ($controls.Present.IsChecked -or !$controls.Automatic.IsChecked) { 'manual' } else { 'automatic' }
        return [pscustomobject]@{session=$id.ToString();minutes=$minutes;prompt=$controls.Prompt.Text;approvalMode=$mode}
    }
    function Start-QuotaJob([string]$purpose) {
        if ($script:job) { throw 'Попередня операція ще виконується' }
        $script:quotaCancelled = $false
        $script:jobKind = $purpose
        Save-CurrentPreferences
        $script:job = Start-Job -ScriptBlock { param($adapter,$root) $ErrorActionPreference='Stop'; Set-Location -LiteralPath $root; & $adapter } -ArgumentList (Join-Path $PSScriptRoot 'Адаптери/Ліміти-Codex.ps1'),$projectRoot
        $controls.Status.Text = 'Читання квот…'
    }
    function Start-NameJob {
        if ($script:job) { throw 'Дочекайтеся завершення поточної операції' }
        $id=[guid]::Empty
        if (![guid]::TryParse($controls.Session.Text.Trim(),[ref]$id) -or $id -eq [guid]::Empty) { throw 'Спочатку вкажіть дійсний UUID' }
        Save-CurrentPreferences
        $script:jobKind='session-name'
        $script:job=Start-Job -ScriptBlock {
            param($adapter,$session)
            $ErrorActionPreference='Stop'
            & $adapter -SessionId $session
        } -ArgumentList (Join-Path $PSScriptRoot 'Адаптери/Назва-Codex.ps1'),$id.ToString()
        $controls.ChatName.Tag=''
        $controls.ChatName.Text='Отримання назви…'
    }
    $controls.History.Add_SelectionChanged({
        if ($controls.History.SelectedItem) {
            $entry = $controls.History.SelectedItem.entry
            $controls.Prompt.Text = $entry.prompt
            $controls.Session.Text = $entry.session
        }
    })
    $controls.Prompt.Add_TextChanged({ $script:editedAt = [DateTime]::UtcNow })
    $controls.Session.Add_TextChanged({
        $script:editedAt = [DateTime]::UtcNow
        if ($controls.ChatName.Tag -ne $controls.Session.Text.Trim()) { $controls.ChatName.Tag=''; $controls.ChatName.Text='Назва ще не отримана' }
    })
    $controls.Session.Add_LostFocus({ try { Save-CurrentPreferences } catch { $controls.Status.Text='Не вдалося зберегти UUID' } })
    $controls.RefreshName.Add_Click({ try { Start-NameJob } catch { $controls.Status.Text=$_.Exception.Message } })
    $controls.SelectCodex.Add_Click({
        try {
            if ($script:job) { throw 'Дочекайтеся завершення поточної операції' }
            $picker=[Microsoft.Win32.OpenFileDialog]::new()
            $picker.Filter='Codex executable (codex.exe)|codex.exe'
            $picker.Title='Оберіть встановлений codex.exe'
            if ($picker.ShowDialog($window)) {
                $script:codexExecutable=$picker.FileName
                Save-CurrentPreferences
                $controls.Quota.Text='Шлях Codex збережено. Натисніть Перевірити квоти.'
            }
        } catch { $controls.Status.Text=$_.Exception.Message }
    })
    $controls.NewPrompt.Add_Click({
        try { Save-Draft; $controls.Prompt.Clear(); $controls.History.SelectedIndex = -1; $null = $controls.Prompt.Focus() }
        catch { $controls.Status.Text = 'Не вдалося зберегти попередню чернетку' }
    })
    $controls.SavePrompt.Add_Click({ try { Save-Draft; $controls.Status.Text = 'Запит збережено в історії' } catch { $controls.Status.Text = 'Не вдалося зберегти запит' } })
    $controls.SendNow.Add_Click({
        try {
            if ($script:job) { throw 'Дочекайтеся завершення поточної перевірки або доставки' }
            # Для одноразової доставки ручне поле часу не потрібне.
            $script:inputs = Read-Inputs -UseAutomaticInterval
            Save-Draft
            Stop-Automation 'Поточний відлік скасовано для одноразової доставки'
            $controls.Repeat.IsChecked = $false
            $script:inputs.approvalMode = 'manual'
            Start-QuotaJob 'send-now'
        } catch { $controls.Status.Text = $_.Exception.Message }
    })
    $controls.SentOnly.Add_Checked({ Refresh-History })
    $controls.SentOnly.Add_Unchecked({ Refresh-History })
    $controls.Journal.Add_Click({
        try {
            $records = @(Read-AILangDecisions)
            $viewer = [Windows.Window]::new()
            $viewer.Title = 'AILang · останні 300 записів рішень'
            $viewer.Width = 850; $viewer.Height = 520; $viewer.Owner = $window
            $text = [Windows.Controls.TextBox]::new()
            $text.IsReadOnly = $true; $text.TextWrapping = 'Wrap'; $text.VerticalScrollBarVisibility = 'Auto'
            $text.Text = if ($records.Count) { ($records | ForEach-Object { '{0} · {1} · {2} · {3} · {4}{5}{6}{5}{7}' -f $_.utc,$_.requestId,$_.mode,$_.source,$_.decision,[Environment]::NewLine,$_.action,$_.reason }) -join ([Environment]::NewLine + [Environment]::NewLine) } else { 'Рішень ще немає. Запуск таймера не є схваленням дії.' }
            $viewer.Content = $text; $null = $viewer.ShowDialog()
        } catch { $controls.Status.Text = 'Журнал недоступний; фактичного схвалення не підтверджено' }
    })
    $presenceChanged = {
        $controls.ApprovalStatus.Text = if ($controls.Present.IsChecked) { 'Наступний запит: ручні схвалення. Для поточної роботи оберіть Ask for approval у чаті.' } else { 'Якщо надсилання ввімкнене: штатний auto-review з обґрунтуванням і локальним журналом; відмова не обходиться.' }
    }
    $controls.Present.Add_Checked($presenceChanged)
    $controls.Present.Add_Unchecked($presenceChanged)
    $controls.Start.Add_Click({
        try {
            if ($script:job) { throw 'Дочекайтеся завершення поточної операції' }
            $script:inputs = Read-Inputs
            Save-Draft
            $script:timerMode = 'manual'
            $script:intervalMinutes = $script:inputs.minutes
            $script:due = [DateTime]::UtcNow.AddMinutes($script:inputs.minutes)
            $script:armed = $true
            $controls.Status.Text = 'Таймер запущено; надсилання можливе лише з увімкненою автоматикою'
        } catch { $controls.Status.Text = $_.Exception.Message }
    })
    $controls.AutoStart.Add_Click({
        try {
            if ($script:job) { throw 'Дочекайтеся завершення поточної операції' }
            $script:inputs = Read-Inputs -UseAutomaticInterval
            Save-Draft
            $script:timerMode = 'automatic'
            $script:intervalMinutes = 305
            $controls.Automatic.IsChecked = $true
            $controls.Repeat.IsChecked = $true
            # Присутність автора не змінюється приховано: позначка Я за ПК має пріоритет.
            $script:due = [DateTime]::UtcNow.AddMinutes(305)
            $script:armed = $true
            $controls.Status.Text = 'Автоматичний цикл 05:05 запущено. Для роботи без автора зніміть Я за ПК.'
        } catch { $controls.Status.Text = $_.Exception.Message }
    })
    $controls.Stop.Add_Click({ Stop-Automation 'Очікування зупинено. Уже надісланий запит не скасовується.' })
    $controls.Automatic.Add_Unchecked({
        # Не скасовуємо вже прийнятий запит і не вдаємо, що його відкликано.
        if (!$script:job -or $script:jobKind -ne 'send') { $controls.Status.Text = 'Надсилання вимкнене; таймер може працювати як нагадування' }
    })
    $controls.Limits.Add_Click({ try { Start-QuotaJob 'display' } catch { $controls.Status.Text = $_.Exception.Message } })
    $controls.Reset.Add_Click({
        try {
            if ($script:job) { throw 'Попередня операція ще виконується' }
            $script:inputs = Read-Inputs -UseAutomaticInterval:($script:timerMode -eq 'automatic')
            $script:intervalMinutes = if ($script:timerMode -eq 'automatic') { 305 } else { $script:inputs.minutes }
            Save-Draft; Start-QuotaJob 'reset'
        }
        catch { $controls.Status.Text = $_.Exception.Message }
    })
    function Update-Timer {
        if ($script:editedAt -and ([DateTime]::UtcNow - $script:editedAt).TotalSeconds -ge 2) { Save-Draft }
        if ($script:armed -and (Get-SettingsFingerprint) -ne $settingsFingerprint) {
            Stop-Automation 'Налаштування змінено. Перегляньте вплив і знову відкрийте планувальник.'
        }
        if ($script:job -and $script:job.State -in @('Completed','Failed','Stopped')) {
            $finishedKind = $script:jobKind
            $failed = $script:job.State -ne 'Completed' -or $script:job.ChildJobs[0].Error.Count -gt 0
            $data = @(Receive-Job -Job $script:job -ErrorAction SilentlyContinue)
            Remove-Job -Job $script:job
            $script:job = $null
            if ($finishedKind -eq 'session-name') {
                $metadata=$data | Select-Object -Last 1
                if (!$failed -and $metadata -and $metadata.session -eq $controls.Session.Text.Trim() -and $metadata.name) {
                    $controls.ChatName.Tag=$metadata.session
                    $controls.ChatName.Text=$metadata.name
                    Save-CurrentPreferences
                } else { $controls.ChatName.Tag=''; $controls.ChatName.Text='Назва чату недоступна; UUID працює без назви' }
                return
            }
            if ($failed) {
                if ($finishedKind -eq 'send') { Add-AILangDecision -RequestId $script:deliveryId -SessionId $script:inputs.session -Mode $script:inputs.approvalMode -Decision failed -Source scheduler -Action 'Доставка queue' -Reason 'Результат доставки невідомий або помилка; повтор вимкнений' }
                Stop-Automation 'Операція завершилася помилкою. Перевірте стан сеансу; автоматичного повтору немає.'; return
            }
            if ($finishedKind -eq 'send') {
                Add-AILangHistory 'прийнято queue' $script:inputs.prompt $script:inputs.session
                Add-AILangDecision -RequestId $script:deliveryId -SessionId $script:inputs.session -Mode $script:inputs.approvalMode -Decision executed -Source scheduler -Action 'Доставка queue' -Reason 'CLI прийняла доставку; це не схвалення наступних операцій агента'
                Refresh-History
                $controls.Status.Text = 'Queue прийняла запит. Це не підтвердження завершення роботи агента.'
                if ($controls.Repeat.IsChecked -and $controls.Automatic.IsChecked -and $script:armed) {
                    $script:due = [DateTime]::UtcNow.AddMinutes($script:intervalMinutes)
                } else { $script:due = $null; $script:armed = $false }
                return
            }
            if ($script:quotaCancelled -and $finishedKind -ne 'display') {
                $controls.Status.Text = 'Очікування зупинено; завершене читання квот не запускає його повторно'
                return
            }
            $quota = $data | Select-Object -Last 1
            if (!$quota -or $quota.status -ne 'known') {
                $controls.Quota.Text = if ($quota.reason) { $quota.reason + ' [' + $quota.code + ']' } else { 'Квоти невідомі: перевірте CLI/авторизацію/мережу' }
                Stop-Automation 'Без достовірних квот автоматичне надсилання зупинено'
                return
            }
            $controls.Quota.Text = (@($quota.windows | ForEach-Object { '{0} хв: залишок {1}%, відновлення UTC {2}' -f $_.minutes,$_.remaining,$_.resetUtc }) -join "`n")
            $short = @($quota.windows | Where-Object minutes -eq 300)
            $week = @($quota.windows | Where-Object minutes -eq 10080)
            $blocked = @($quota.windows | Where-Object { ($_.minutes -eq 300 -and $_.remaining -le 10) -or ($_.minutes -eq 10080 -and $_.remaining -le 5) -or $_.remaining -le 0 })
            if ($finishedKind -eq 'display') { $controls.Status.Text = 'Квоти прочитано; запит не надсилався'; return }
            if (!$short.Count -or !$week.Count) { Stop-Automation 'Набір вікон квот не відповідає налаштованій політиці 5 годин / тиждень. Потрібна адаптація.'; return }
            if ($finishedKind -eq 'send-now' -and $blocked.Count) {
                Stop-Automation 'Недостатньо квот для негайного надсилання. Запит не надіслано; автоматичного повтору немає.'
                return
            }
            if ($finishedKind -eq 'reset' -or $blocked.Count) {
                $resets = @($blocked | Where-Object resetUtc | ForEach-Object { [DateTime]::Parse($_.resetUtc).ToUniversalTime() })
                if ($blocked.Count -and $resets.Count -eq $blocked.Count) {
                    $script:due = ($resets | Sort-Object -Descending | Select-Object -First 1).AddMinutes(5)
                    if ($script:due -le [DateTime]::UtcNow) { Stop-Automation 'Відновлення не підтверджено після очікуваного часу'; return }
                    $script:armed = $true
                    $controls.Status.Text = 'Очікування останнього обмежувального вікна + 5 хв; потім нова перевірка'
                } elseif ($blocked.Count) { Stop-Automation 'Час відновлення невідомий' }
                else { $controls.Status.Text = 'Квоти дозволяють роботу; запустіть таймер на потрібний час' }
                return
            }
            if ($finishedKind -ne 'send-now' -and (!$script:armed -or !$controls.Automatic.IsChecked)) { $controls.Status.Text = 'Надсилання вимкнене'; return }
            if ((Get-SettingsFingerprint) -ne $settingsFingerprint) { Stop-Automation 'Конфігурація змінилася; потрібен повторний перегляд'; return }
            # Перед доставкою перечитати присутність автора, але не підміняти знімок тексту/сеансу.
            $script:inputs.approvalMode = if ($finishedKind -eq 'send-now' -or $controls.Present.IsChecked) { 'manual' } else { 'automatic' }
            $outgoing = New-AILangScheduledPrompt -Prompt $script:inputs.prompt -SessionId $script:inputs.session -Mode $script:inputs.approvalMode
            if ($outgoing.Length -gt 24000) { Stop-Automation 'Запит із правилами журналювання задовгий; скоротіть власний текст'; return }
            $script:deliveryId = [guid]::NewGuid().ToString()
            Add-AILangDecision -RequestId $script:deliveryId -SessionId $script:inputs.session -Mode $script:inputs.approvalMode -Decision requested -Source scheduler -Action 'Доставка queue' -Reason 'Квоти перевірені; обраний користувачем режим наступного запиту'
            Add-AILangHistory 'спроба надсилання' $script:inputs.prompt $script:inputs.session
            Refresh-History
            $script:jobKind = 'send'
            $script:job = Start-Job -ScriptBlock {
                param($adapter,$root,$session,$prompt,$mode)
                $ErrorActionPreference = 'Stop'
                & $adapter -SessionId $session -Prompt $prompt -ProjectRoot $root -ApprovalMode $mode
            } -ArgumentList (Join-Path $PSScriptRoot 'Адаптери/Надіслати-Codex.ps1'),$projectRoot,$script:inputs.session,$outgoing,$script:inputs.approvalMode
            $controls.Status.Text = 'Доставка в наявний чат через queue; очікування підтвердження прийняття'
        }
        if ($script:due) {
            $left = [Math]::Max(0,($script:due - [DateTime]::UtcNow).TotalSeconds)
            $span = [TimeSpan]::FromSeconds([Math]::Ceiling($left))
            $controls.Countdown.Text = '{0:00}:{1:00}:{2:00}' -f [int][Math]::Floor($span.TotalHours),$span.Minutes,$span.Seconds
            if ($left -le 0 -and !$script:job) {
                $script:due = $null
                if ($controls.Automatic.IsChecked -and $script:armed) { $script:inputs = Read-Inputs -UseAutomaticInterval:($script:timerMode -eq 'automatic'); Save-Draft; Start-QuotaJob 'before-send' }
                else { $script:armed = $false; $controls.Status.Text = 'Час настав. Автоматичне надсилання вимкнене.' }
            }
        } elseif (!$script:job) { $controls.Countdown.Text = '—' }
    }
    Refresh-History
    Save-CurrentPreferences
    if ($controls.Session.Text -and $script:codexExecutable) { try { Start-NameJob } catch {} }
    $timer = [Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Add_Tick({ try { Update-Timer } catch { Stop-Automation 'Помилка локального стану або параметрів; очікування зупинено' } })
    $window.Add_Closing({
        $closingArgs=$_
        if ($script:job -and $script:jobKind -eq 'send') {
            $_.Cancel = $true
            $controls.Status.Text = 'Queue ще передає запит. Вимкніть повтор і дочекайтеся підтвердження перед закриттям.'
        } else {
            try { Save-Draft } catch { $closingArgs.Cancel=$true; $controls.Status.Text='Не вдалося зберегти UUID/чернетку. Перевірте доступ до локального стану.' }
        }
    })
    $window.Add_Closed({ $timer.Stop() })
    $timer.Start()
    $null = $window.ShowDialog()
} catch {
    # Зовнішній Launch.ps1 охоплює також імпорт модулів до цього try.
    throw
} finally {
    if ($script:job) { Stop-Job -Job $script:job; Remove-Job -Job $script:job }
    if ($ownsMutex) { $instance.ReleaseMutex() }
    $instance.Dispose()
}
