param(
    [ValidateRange(15, 300)]
    [int]$DelaySeconds = 45
)

# Запускається лише після явного доручення власника вимкнути комп’ютер.
# Штатне вимкнення не примушує застосунки закрити незбережені документи.
Start-Sleep -Seconds $DelaySeconds
& shutdown.exe /s /t 0
exit $LASTEXITCODE
