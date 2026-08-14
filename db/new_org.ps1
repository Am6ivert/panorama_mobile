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

# Значения передаём НЕ аргументами -v, а временным файлом в UTF-8.
#
# Windows PowerShell 5.1 кодирует аргументы внешних программ в ANSI, а psql у
# нас работает в UTF-8: латиница проходила, а кириллица превращалась в
# "неверный многобайтный символ", и переменная просто не устанавливалась.
# Файлы psql читает в кодировке PGCLIENTENCODING, поэтому здесь всё корректно.
function Esc([string]$v) { return $v -replace "'", "\'" }

$varsFile = Join-Path ([System.IO.Path]::GetTempPath()) "panorama_new_org_$PID.sql"
$vars = @(
  "\set code '$(Esc $Code)'",
  "\set name '$(Esc $Name)'",
  "\set admin_name '$(Esc $AdminName)'",
  "\set admin_login '$(Esc $AdminLogin)'",
  "\set admin_phone '$(Esc $AdminPhone)'"
) -join "`n"

# Без BOM: psql принимает его за часть первой команды.
[System.IO.File]::WriteAllText($varsFile, $vars + "`n",
                               (New-Object System.Text.UTF8Encoding $false))

try {
  & $psql -U $User -h $DbHost -d $Database -v ON_ERROR_STOP=1 `
          -f $varsFile `
          -f (Join-Path $dbDir 'new_org.sql')
  $code = $LASTEXITCODE
} finally {
  Remove-Item $varsFile -ErrorAction SilentlyContinue
  $env:PGPASSWORD = $null
}

if ($code -ne 0) { throw "Компанию завести не удалось - см. сообщение выше." }

Write-Host "`nГотово. Вход: логин '$AdminLogin', пароль '0000' (приложение попросит сменить)." -ForegroundColor Green
