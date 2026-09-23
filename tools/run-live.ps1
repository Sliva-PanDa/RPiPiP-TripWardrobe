# Запуск приложения в браузере без захода на сайт GitHub.
#
# Скрипт запускает сценарий live-demo.yml, ждёт появления ссылки,
# печатает её с паролем и открывает в браузере.

$ErrorActionPreference = "Stop"

$Repo = "Sliva-PanDa/RPiPiP-TripWardrobe"
$Gh   = "C:\Program Files\GitHub CLI\gh.exe"

function Write-Step($text) { Write-Host "`n>> $text" -ForegroundColor Cyan }

if (-not (Test-Path $Gh)) {
    Write-Host "Не найден GitHub CLI: $Gh" -ForegroundColor Red
    Write-Host "Поставь его командой: winget install GitHub.cli"
    Read-Host "Enter - выход"
    exit 1
}

Write-Host "Запуск приложения <<Гардероб>> в браузере" -ForegroundColor Green
Write-Host "Ветки: main - итоговая версия; lab1, lab2, lab3, lab4 - по лабораторным"

$branch = Read-Host "Ветка (Enter = main)"
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "main" }

$device = Read-Host "Устройство (Enter = iPhone; можно iPad)"
if ([string]::IsNullOrWhiteSpace($device)) { $device = "iPhone" }

$minutes = Read-Host "Сколько минут держать сеанс (Enter = 60)"
if ([string]::IsNullOrWhiteSpace($minutes)) { $minutes = "60" }

Write-Step "Запускаю: ветка $branch, устройство $device, $minutes мин"
& $Gh workflow run live-demo.yml --repo $Repo --ref main `
      -f ref=$branch -f device=$device -f minutes=$minutes
Start-Sleep -Seconds 12

$runId = (& $Gh run list --repo $Repo --workflow live-demo.yml --limit 1 `
            --json databaseId | ConvertFrom-Json).databaseId
Write-Host "Запуск №$runId - https://github.com/$Repo/actions/runs/$runId"

Write-Step "Готовлю симулятор. Это 10-12 минут, окно можно свернуть."
$started = Get-Date
$link = $null
$password = $null

while ($true) {
    Start-Sleep -Seconds 20
    $elapsed = [int]((Get-Date) - $started).TotalMinutes
    $run = & $Gh run view $runId --repo $Repo --json status,conclusion,jobs | ConvertFrom-Json

    # Сценарий выкладывает ссылку и пароль отдельным файлом: его можно
    # скачать сразу, не дожидаясь окончания сеанса.
    $step = $run.jobs[0].steps | Where-Object { $_.name -like "Опубликовать файл*" }
    if ($step -and $step.conclusion -eq "success") {
        $temp = Join-Path $env:TEMP "tripwardrobe-link"
        if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
        & $Gh run download $runId --repo $Repo -n link -D $temp | Out-Null

        $lines = Get-Content (Join-Path $temp "link.txt")
        $link = $lines[0].Trim()
        $password = $lines[1].Trim()

        Write-Step "Готово"
        Write-Host "  ССЫЛКА: $link"   -ForegroundColor Green
        Write-Host "  ПАРОЛЬ: $password" -ForegroundColor Yellow
        Set-Clipboard -Value $password
        Write-Host "  (пароль уже скопирован в буфер обмена - вставь Ctrl+V)"
        Start-Process $link
        break
    }

    $failed = $run.jobs[0].steps | Where-Object { $_.conclusion -eq "failure" }
    if ($failed) {
        Write-Host "Шаг <<$($failed[0].name)>> завершился ошибкой." -ForegroundColor Red
        Start-Process "https://github.com/$Repo/actions/runs/$runId"
        Read-Host "Enter - выход"
        exit 1
    }

    if ($run.status -eq "completed") {
        Write-Host "Запуск завершился: $($run.conclusion)" -ForegroundColor Red
        Start-Process "https://github.com/$Repo/actions/runs/$runId"
        Read-Host "Enter - выход"
        exit 1
    }

    Write-Host ("  [{0,2} мин] идёт подготовка..." -f $elapsed)

    if ($elapsed -gt 30) {
        Write-Host "Слишком долго, открой страницу запуска вручную." -ForegroundColor Red
        Start-Process "https://github.com/$Repo/actions/runs/$runId"
        Read-Host "Enter - выход"
        exit 1
    }
}

Write-Host ""
Write-Host "Сеанс закроется сам через $minutes мин." -ForegroundColor Green
Write-Host "Закончить раньше: на странице запуска кнопка Cancel workflow."
Read-Host "Enter - выход"
