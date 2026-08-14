# =============================================================================
# Прогон тестов бэкенда.
#
#   powershell -ExecutionPolicy Bypass -File backend\run_tests.ps1
#
# Что делает:
#   1. пересоздаёт ОТДЕЛЬНУЮ базу panorama_test (рабочая panorama не трогается);
#   2. накатывает schema.sql и seed.sql;
#   3. запускает dart test.
#
# Только быстрые тесты, без базы и без PostgreSQL:
#   powershell -ExecutionPolicy Bypass -File backend\run_tests.ps1 -UnitOnly
#
# ЗАЩИТА: скрипт откажется работать, если имя базы не заканчивается на _test.
# =============================================================================
param(
  [string]$DbHost   = 'localhost',
  [string]$Database = 'panorama_test',
  [string]$User     = 'panorama',
  [string]$Password = 'panorama',
  [switch]$UnitOnly,
  # Пароль суперпользователя postgres. Если не задан - скрипт спросит.
  [string]$SuperPassword
)

$ErrorActionPreference = 'Stop'
$backendDir = $PSScriptRoot
if (-not $backendDir) { $backendDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$dbDir = Join-Path (Split-Path -Parent $backendDir) 'db'

if ($Database -notmatch '_test$') {
  throw "Отказ: '$Database' не похоже на тестовую базу (имя должно заканчиваться на _test). Это защита от запуска по рабочей базе."
}


# Распознаём известную поломку разрешения пакетов и объясняем, что делать.
function Show-PackageConfigHint($text) {
  if ("$text" -notmatch 'did not contain its own root package') { return $false }
  Write-Host ""
  Write-Host "=== Не тесты виноваты: dart test не смог разрешить корневой пакет ===" -ForegroundColor Yellow
  Write-Host "Файл .dart_tool\package_config.json корректен (panorama_backend в нём есть)."
  Write-Host "Почти всегда причина - НЕЛАТИНСКИЕ СИМВОЛЫ В ПУТИ к проекту:"
  Write-Host "    $((Get-Item $PSScriptRoot).FullName)" -ForegroundColor Gray
  Write-Host ""
  Write-Host "Проверить за минуту - скопировать бэкенд в путь без кириллицы:" -ForegroundColor Cyan
  Write-Host '    robocopy "<путь к backend>" D:\tmp\pb /E /XD .dart_tool build > $null'
  Write-Host '    cd D:\tmp\pb; dart pub get; dart test test\unit_test.dart'
  Write-Host ""
  Write-Host "Если там тесты проходят - лечится переименованием папки"
  Write-Host "'Новая папка' во что-то латиницей, например 'panorama'."
  return $true
}

# --- Быстрые тесты без базы --------------------------------------------------
if ($UnitOnly) {
  Push-Location $backendDir
  try {
    # ErrorActionPreference=Stop превращает ЛЮБУЮ строку stderr внешней
    # программы в исключение, и прогон обрывался на первом же сообщении.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & dart test test/unit_test.dart 2>&1 | ForEach-Object { Write-Host $_; $_ }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
  } finally { Pop-Location }
  if ($code -ne 0) {
    if (-not (Show-PackageConfigHint $out)) { Write-Host "Юнит-тесты не прошли." -ForegroundColor Red }
    exit 1
  }
  Write-Host "`nЮнит-тесты пройдены." -ForegroundColor Green
  exit 0
}

. (Join-Path $dbDir '_psql.ps1')
$psql = Find-Psql
Write-Host "psql: $psql" -ForegroundColor Cyan

# --- Пересоздание тестовой базы ---------------------------------------------
if (-not $SuperPassword) {
  $sec = Read-Host "Пароль суперпользователя 'postgres' (нужен только для пересоздания $Database)" -AsSecureString
  $SuperPassword = [System.Net.NetworkCredential]::new('', $sec).Password
}
$env:PGPASSWORD = $SuperPassword

Write-Host "`n[1/4] Пересоздаю базу $Database..." -ForegroundColor Green
& $psql -U postgres -h $DbHost -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS $Database WITH (FORCE);"
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "Не удалось удалить $Database (неверный пароль postgres?)." }
& $psql -U postgres -h $DbHost -v ON_ERROR_STOP=1 -c "CREATE DATABASE $Database OWNER $User;"
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "Не удалось создать $Database." }
& $psql -U postgres -h $DbHost -d $Database -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS pgcrypto; GRANT ALL ON SCHEMA public TO $User; ALTER SCHEMA public OWNER TO $User;"
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "Не удалось подготовить $Database." }

$env:PGPASSWORD = $Password

Write-Host "[2/4] Схема..." -ForegroundColor Green
& $psql -U $User -h $DbHost -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'schema.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "schema.sql не накатился." }

Write-Host "[3/4] Начальные данные..." -ForegroundColor Green
& $psql -U $User -h $DbHost -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'seed.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "seed.sql не накатился." }

# --- Тесты -------------------------------------------------------------------
Write-Host "[4/4] dart test..." -ForegroundColor Green
$env:PGHOST     = $DbHost
$env:PGDATABASE = $Database
$env:PGUSER     = $User

Push-Location $backendDir
try {
  $prevEAP = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = & dart test 2>&1 | ForEach-Object { Write-Host $_; $_ }
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prevEAP
} finally {
  Pop-Location
  $env:PGPASSWORD = $null
  Remove-Item Env:PGHOST, Env:PGDATABASE, Env:PGUSER -ErrorAction SilentlyContinue
}

if ($code -ne 0) {
  if (-not (Show-PackageConfigHint $out)) { Write-Host "Тесты не прошли (см. вывод выше)." -ForegroundColor Red }
  exit 1
}
Write-Host "`nВсе тесты пройдены." -ForegroundColor Green
