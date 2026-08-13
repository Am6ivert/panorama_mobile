# =============================================================================
# Накатывает миграции на УЖЕ РАБОТАЮЩУЮ базу panorama. Данные не удаляет.
#
# Запуск (из любой папки):
#   powershell -ExecutionPolicy Bypass -File "D:\works\panorama\Новая папка\panorama_mobile\db\migrate.ps1"
#
# Для чистой установки с нуля используйте db\setup.ps1 - он ПЕРЕСОЗДАЁТ базу.
# =============================================================================
param(
  [string]$DbHost   = 'localhost',
  [string]$Database = 'panorama',
  [string]$User     = 'panorama',
  [string]$Password = 'panorama'
)

$ErrorActionPreference = 'Stop'
$dbDir = $PSScriptRoot
if (-not $dbDir) { $dbDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $dbDir '_psql.ps1')

$psql = Find-Psql
Write-Host "psql: $psql" -ForegroundColor Cyan
$env:PGPASSWORD = $Password

function Query([string]$sql) {
  (& $psql -U $User -h $DbHost -d $Database -tAc $sql 2>$null) -join ''
}

function RunFile([string]$file) {
  & $psql -U $User -h $DbHost -d $Database -v ON_ERROR_STOP=1 -f (Join-Path $dbDir $file)
  if ($LASTEXITCODE -ne 0) { $env:PGPASSWORD = $null; throw "$file - ошибка, см. вывод выше." }
}

# --- Есть ли вообще база? ----------------------------------------------------
$alive = Query 'SELECT 1'
if ($alive -ne '1') {
  $env:PGPASSWORD = $null
  throw @"
Не удалось подключиться к базе '$Database' на $DbHost под ролью '$User'.
Если база ещё не создана - сначала выполните:
    powershell -ExecutionPolicy Bypass -File "$dbDir\setup.ps1"
(внимание: setup.ps1 пересоздаёт базу начисто).
"@
}

Write-Host "`n=== Состояние базы ===" -ForegroundColor Cyan
$has001 = (Query "SELECT to_regclass('public.sessions') IS NOT NULL AND EXISTS(SELECT 1 FROM pg_indexes WHERE indexname='sessions_token_hash_uniq')") -eq 't'
$has002 = (Query "SELECT to_regclass('public.organizations') IS NOT NULL") -eq 't'
$has003 = (Query "SELECT to_regclass('public.companies') IS NULL AND NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND column_name='company_id')") -eq 't'
$has004 = (Query "SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='devices_user_idx') AND EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='apartments_hold_expiry_idx')") -eq 't'
$has005 = (Query "SELECT data_type='bigint' FROM information_schema.columns WHERE table_schema='public' AND table_name='complexes' AND column_name='cover_start'") -eq 't'
$has006 = (Query "SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='apartments_org_updated_idx')") -eq 't'
$has007 = (Query "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='settings' AND column_name='org_id')") -eq 't'
$has008 = (Query "SELECT EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='users_login_uniq') AND NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='apartments' AND column_name='is_penthouse')") -eq 't'
$has009 = (Query "SELECT to_regclass('public.subscriptions') IS NOT NULL AND EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='organizations' AND column_name='plan_until')") -eq 't'
$has010 = (Query "SELECT is_nullable='NO' AND column_default IS NOT NULL FROM information_schema.columns WHERE table_schema='public' AND table_name='organizations' AND column_name='plan_until'") -eq 't'
Write-Host ("  001 (хеширование токенов): {0}" -f $(if ($has001) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  002 (компании / org_id)  : {0}" -f $(if ($has002) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  003 (снос legacy company): {0}" -f $(if ($has003) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  004 (индексы под запросы): {0}" -f $(if ($has004) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  005 (цвет обложки bigint): {0}" -f $(if ($has005) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  006 (дельта-выдача фонда) : {0}" -f $(if ($has006) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  007 (настройки по компаниям): {0}" -f $(if ($has007) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  008 (уникальность логинов): {0}" -f $(if ($has008) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  009 (подписки, суперадмин): {0}" -f $(if ($has009) { 'уже накачена' } else { 'нужна' }))
Write-Host ("  010 (пробные 3 дня по умолчанию): {0}" -f $(if ($has010) { 'уже накачена' } else { 'нужна' }))

if ($has001 -and $has002 -and $has003 -and $has004 -and $has005 -and $has006 -and $has007 -and $has008 -and $has009 -and $has010) {
  Write-Host "`nМиграции уже накачены - показываю только отчёт." -ForegroundColor Green
}

if (-not $has001) {
  Write-Host "`n[1] 001_auth_hardening.sql - токены переходят на SHA-256." -ForegroundColor Green
  Write-Host "    Все текущие сессии будут отозваны: пользователи войдут заново." -ForegroundColor Yellow
  RunFile 'migrations\001_auth_hardening.sql'
} else {
  Write-Host "`n[1] 001 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has002) {
  Write-Host "`n[2] 002_multi_tenant.sql - компании и org_id." -ForegroundColor Green
  Write-Host "    Все существующие данные переедут в компанию 'panorama'." -ForegroundColor Yellow
  RunFile 'migrations\002_multi_tenant.sql'
} else {
  Write-Host "`n[2] 002 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has003) {
  Write-Host "`n[3] 003_drop_legacy_company.sql - снос старого механизма компаний." -ForegroundColor Green
  Write-Host "    companies/company_id не используются кодом и мешают вставкам." -ForegroundColor Yellow
  RunFile 'migrations\003_drop_legacy_company.sql'
} else {
  Write-Host "`n[3] 003 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has004) {
  Write-Host "`n[4] 004_indexes.sql - индексы под push и проверку броней." -ForegroundColor Green
  RunFile 'migrations\004_indexes.sql'
} else {
  Write-Host "`n[4] 004 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has005) {
  Write-Host "`n[5] 005_cover_bigint.sql - цвет обложки не помещался в integer." -ForegroundColor Green
  Write-Host "    Из-за этого падало создание любого объекта." -ForegroundColor Yellow
  RunFile 'migrations\005_cover_bigint.sql'
} else {
  Write-Host "`n[5] 005 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has006) {
  Write-Host "`n[6] 006_units_delta.sql - индекс под инкрементальную выдачу фонда." -ForegroundColor Green
  RunFile 'migrations\006_units_delta.sql'
} else {
  Write-Host "`n[6] 006 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has007) {
  Write-Host "`n[7] 007_settings_per_org.sql - лимиты становятся настройкой компании." -ForegroundColor Green
  RunFile 'migrations\007_settings_per_org.sql'
} else {
  Write-Host "`n[7] 007 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has008) {
  Write-Host "`n[8] 008_restore_user_uniq.sql - возврат уникальности логина и телефона." -ForegroundColor Green
  Write-Host "    В рабочей базе этих индексов не было: два пользователя могли иметь один логин." -ForegroundColor Yellow
  RunFile 'migrations\008_restore_user_uniq.sql'
} else {
  Write-Host "`n[8] 008 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has009) {
  Write-Host "`n[9] 009_subscriptions.sql - подписки компаний и роль суперадминистратора." -ForegroundColor Green
  Write-Host "    Работающим компаниям выдаётся месяц, чтобы никого не отключить." -ForegroundColor Yellow
  RunFile 'migrations\009_subscriptions.sql'
} else {
  Write-Host "`n[9] 009 пропущена - уже накачена." -ForegroundColor DarkGray
}

if (-not $has010) {
  Write-Host "`n[10] 010_trial_by_default.sql - пробные 3 дня становятся умолчанием таблицы." -ForegroundColor Green
  Write-Host "     Раньше их выдавал только new_org.ps1: компания, заведённая иначе," -ForegroundColor Yellow
  Write-Host "     сразу попадала в режим только чтения." -ForegroundColor Yellow
  RunFile 'migrations\010_trial_by_default.sql'
} else {
  Write-Host "`n[10] 010 пропущена - уже накачена." -ForegroundColor DarkGray
}

Write-Host "`n=== Проверка ===" -ForegroundColor Cyan
# Запрос кладём в файл, а не в -c: PowerShell 5.1 отдаёт аргументы внешним
# программам в кодировке ANSI, из-за чего русские алиасы приезжают битыми.
& $psql -U $User -h $DbHost -d $Database -f (Join-Path $dbDir 'verify.sql')

Write-Host "`n=== Сверка со схемой из репозитория ===" -ForegroundColor Cyan
& $psql -U $User -h $DbHost -d $Database -f (Join-Path $dbDir 'drift.sql')

$env:PGPASSWORD = $null
Write-Host "`nГотово. Дальше: db\new_org.ps1 - если нужна вторая компания." -ForegroundColor Green
