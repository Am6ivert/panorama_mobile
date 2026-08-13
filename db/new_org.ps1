# =============================================================================
# Завести новую строительную компанию и её первого администратора.
#
# Запуск (из любой папки, одной строкой):
#   powershell -ExecutionPolicy Bypass -File "...\db\new_org.ps1" `
#     -Code elitstroy -Name "ЭлитСтрой" `
#     -AdminName "Иванов Иван" -AdminLogin elit.admin -AdminPhone "+996 555 12-34-56"
#
# Без аргументов скрипт спросит всё сам.
# =============================================================================
param(
  [string]$Code,
  [string]$Name,
  [string]$AdminName,
  [string]$AdminLogin,
  [string]$AdminPhone,
  [string]$DbHost   = 'localhost',
  [string]$Database = 'panorama',
  [string]$User     = 'panorama',
  [string]$Password = 'panorama'
)

$ErrorActionPreference = 'Stop'
$dbDir = $PSScriptRoot
if (-not $dbDir) { $dbDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $dbDir '_psql.ps1')

if (-not $Code)       { $Code       = Read-Host 'Код компании (латиницей, напр. elitstroy)' }
if (-not $Name)       { $Name       = Read-Host 'Название компании (напр. ЭлитСтрой)' }
if (-not $AdminName)  { $AdminName  = Read-Host 'ФИО администратора' }
if (-not $AdminLogin) { $AdminLogin = Read-Host 'Логин администратора (уникален во всей базе, напр. elit.admin)' }
if (-not $AdminPhone) { $AdminPhone = Read-Host 'Телефон администратора' }

$psql = Find-Psql
Write-Host "psql: $psql" -ForegroundColor Cyan
$env:PGPASSWORD = $Password

& $psql -U $User -h $DbHost -d $Database -v ON_ERROR_STOP=1 `
        -v "code=$Code" `
        -v "name=$Name" `
        -v "admin_name=$AdminName" `
        -v "admin_login=$AdminLogin" `
        -v "admin_phone=$AdminPhone" `
        -f (Join-Path $dbDir 'new_org.sql')

$code = $LASTEXITCODE
$env:PGPASSWORD = $null
if ($code -ne 0) { throw "Компанию завести не удалось - см. сообщение выше." }

Write-Host "`nГотово. Вход: логин '$AdminLogin', пароль '0000' (приложение попросит сменить)." -ForegroundColor Green
