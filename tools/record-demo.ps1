# Запись видео работы приложения в GitHub Actions и его загрузка на диск.
#
# Скрипт запускает сценарий demo-video.yml, ждёт его завершения и кладёт
# готовый файл в папку «Демонстрация» рядом с репозиторием.

$ErrorActionPreference = "Stop"

$Repo    = "Sliva-PanDa/RPiPiP-TripWardrobe"
$Outputs = "D:\GitHub labs\Демонстрация"
$Gh      = "C:\Program Files\GitHub CLI\gh.exe"

function Write-Step($text) { Write-Host "`n>> $text" -ForegroundColor Cyan }

if (-not (Test-Path $Gh)) {
    Write-Host "Не найден GitHub CLI: $Gh" -ForegroundColor Red
    Write-Host "Поставь его командой: winget install GitHub.cli"
    Read-Host "Enter — выход"
    exit 1
}

# Ветка и устройство можно выбрать, но по умолчанию берётся итоговая версия.
$branch = Read-Host "Ветка (Enter = main; варианты: main, lab1, lab2, lab3, lab4)"
if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "main" }

$device = Read-Host "Устройство (Enter = iPhone; варианты: iPhone, iPad)"
if ([string]::IsNullOrWhiteSpace($device)) { $device = "iPhone" }

Write-Step "Запускаю запись видео: ветка $branch, устройство $device"
& $Gh workflow run demo-video.yml --repo $Repo --ref main -f ref=$branch -f device=$device
Start-Sleep -Seconds 12

$runId = (& $Gh run list --repo $Repo --workflow demo-video.yml --limit 1 --json databaseId |
          ConvertFrom-Json).databaseId
Write-Host "Запуск №$runId — https://github.com/$Repo/actions/runs/$runId"

Write-Step "Жду окончания записи. Обычно 12-16 минут, можно свернуть окно."
$started = Get-Date
while ($true) {
    $run = & $Gh run list --repo $Repo --workflow demo-video.yml --limit 1 `
             --json databaseId,status,conclusion | ConvertFrom-Json
    $elapsed = [int]((Get-Date) - $started).TotalMinutes
    Write-Host ("  [{0,2} мин] {1}" -f $elapsed, $run.status)

    if ($run.status -eq "completed") {
        if ($run.conclusion -ne "success") {
            Write-Host "Запуск завершился с результатом: $($run.conclusion)" -ForegroundColor Red
            Write-Host "Открой https://github.com/$Repo/actions/runs/$($run.databaseId)"
            Read-Host "Enter — выход"
            exit 1
        }
        break
    }
    if ($elapsed -gt 40) {
        Write-Host "Слишком долго, проверь страницу запуска вручную." -ForegroundColor Red
        Read-Host "Enter — выход"
        exit 1
    }
    Start-Sleep -Seconds 30
}

Write-Step "Скачиваю видео"
$temp = Join-Path $env:TEMP "tripwardrobe-demo"
if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
& $Gh run download $runId --repo $Repo -D $temp

$source = Get-ChildItem $temp -Recurse -Filter demo.mp4 | Select-Object -First 1
if (-not $source) {
    Write-Host "Видео в артефактах не найдено." -ForegroundColor Red
    Read-Host "Enter — выход"
    exit 1
}

New-Item -ItemType Directory -Force -Path $Outputs | Out-Null
$target = Join-Path $Outputs ("Приложение на {0} ({1}).mp4" -f $device, $branch)
Copy-Item $source.FullName $target -Force

Write-Step "Готово"
Write-Host $target -ForegroundColor Green
Start-Process explorer.exe "/select,`"$target`""
Read-Host "Enter — выход"
