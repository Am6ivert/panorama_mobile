# =============================================================================
# Настройка БД Panorama одним скриптом.
# Запуск из корня проекта:
#   powershell -ExecutionPolicy Bypass -File db\setup.ps1
# Скрипт спросит пароль суперпользователя 'postgres' (заданный при установке
# PostgreSQL) — он нужен только для создания роли и базы, нигде не сохраняется.
# =============================================================================
$ErrorActionPreference = 'Stop'
$dbDir = $PSScriptRoot
if (-not $dbDir) { $dbDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# --- Найти psql.exe ---------------------------------------------------------
$psql = $null
try {
    $base = (Get-ItemProperty "HKLM:\SOFTWARE\PostgreSQL\Installations\*" -ErrorAction Stop |
             Select-Object -First 1).'Base Directory'
    if ($base) { $psql = Join-Path $base 'bin\psql.exe' }
} catch {}
if (-not $psql -or -not (Test-Path $psql)) {
    $cmd = Get-Command psql.exe -ErrorAction SilentlyContinue
    if ($cmd) { $psql = $cmd.Source }
}
if (-not $psql -or -not (Test-Path $psql)) {
    throw "psql.exe не найден. Пропиши путь вручную в начале скрипта."
}
Write-Host "psql: $psql" -ForegroundColor Cyan

# --- Пароль суперпользователя (вводишь ты) ----------------------------------
$sec = Read-Host "Пароль суперпользователя 'postgres'" -AsSecureString
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $sec).Password

Write-Host "`n[1/3] Роль, база, расширение pgcrypto..." -ForegroundColor Green
& $psql -U postgres -h localhost -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'init.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "init.sql: ошибка (неверный пароль postgres?)." }

# Дальше — под ролью приложения.
$env:PGPASSWORD = 'panorama'

Write-Host "`n[2/3] Схема (таблицы, индексы)..." -ForegroundColor Green
& $psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'schema.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "schema.sql: ошибка." }

Write-Host "`n[3/3] Начальные данные..." -ForegroundColor Green
& $psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'seed.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "seed.sql: ошибка." }

Write-Host "`n=== Проверка ===" -ForegroundColor Cyan
& $psql -U panorama -h localhost -d panorama -c "SELECT count(*) AS apartments FROM apartments;"
& $psql -U panorama -h localhost -d panorama -c "SELECT login, full_name FROM users ORDER BY login;"

$env:PGPASSWORD = $null
Write-Host "`nГотово. База 'panorama', роль 'panorama' (пароль 'panorama'), демо-учётки — пароль 0000." -ForegroundColor Green
