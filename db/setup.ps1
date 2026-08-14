# =============================================================================
# Setup БД Panorama одним скриптом.
# Запуск из корня проекта:
#   powershell -ExecutionPolicy Bypass -File db\setup.ps1
# Скрипт спросит пароль суперпользователя 'postgres' (заданный при установке
# PostgreSQL) - нужен только для создания роли и базы, нигде не сохраняется.
#
# ВНИМАНИЕ: init.sql пересоздаёт базу 'panorama' начисто (DROP + CREATE) -
# запуск повторно безопасен, но все данные в ней будут стёрты.
# =============================================================================
$ErrorActionPreference = 'Stop'
$dbDir = $PSScriptRoot
if (-not $dbDir) { $dbDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# --- Find psql.exe -----------------------------------------------------------
# Поиск psql и PGCLIENTENCODING=UTF8 (иначе на русской Windows psql читает
# .sql как WIN1251 и русские имена из seed.sql попадают в базу мусором).
. (Join-Path $dbDir '_psql.ps1')
$psql = Find-Psql
Write-Host "psql: $psql" -ForegroundColor Cyan

# --- Superuser password (you type it) ----------------------------------------
$sec = Read-Host "Password for superuser 'postgres'" -AsSecureString
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $sec).Password

Write-Host "`n[1/3] Role, database (recreated), pgcrypto extension..." -ForegroundColor Green
& $psql -U postgres -h localhost -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'init.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "init.sql failed (wrong postgres password?)." }

# From here on - as the application role.
$env:PGPASSWORD = 'panorama'

Write-Host "`n[2/3] Schema (tables, indexes)..." -ForegroundColor Green
& $psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'schema.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "schema.sql failed." }

Write-Host "`n[3/3] Seed data..." -ForegroundColor Green
& $psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'seed.sql')
if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD=$null; throw "seed.sql failed." }

Write-Host "`n=== Verification ===" -ForegroundColor Cyan
& $psql -U panorama -h localhost -d panorama -c "SELECT count(*) AS apartments FROM apartments;"
& $psql -U panorama -h localhost -d panorama -c "SELECT login, full_name FROM users ORDER BY login;"

$env:PGPASSWORD = $null
Write-Host "`nDone. Database 'panorama', role 'panorama' (password 'panorama'), demo accounts password 0000." -ForegroundColor Green
