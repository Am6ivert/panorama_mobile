# =============================================================================
# Создать суперадминистратора - учётную запись, которая видит все компании,
# их администраторов и подписки.
#
#   powershell -ExecutionPolicy Bypass -File db\new_superadmin.ps1
#
# Без аргументов скрипт спросит всё сам.
# =============================================================================
param(
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

if (-not $AdminName)  { $AdminName  = Read-Host 'ФИО суперадминистратора' }
if (-not $AdminLogin) { $AdminLogin = Read-Host 'Логин (уникален во всей базе, напр. super)' }
if (-not $AdminPhone) { $AdminPhone = Read-Host 'Телефон' }

$psql = Find-Psql
Write-Host "psql: $psql" -ForegroundColor Cyan
$env:PGPASSWORD = $Password

# Значения передаём файлом в UTF-8, а не аргументами -v: PowerShell 5.1
# кодирует аргументы внешних программ в ANSI, и кириллица приезжает мусором.
function Esc([string]$v) { return $v -replace "'", "\'" }

$varsFile = Join-Path ([System.IO.Path]::GetTempPath()) "panorama_su_$PID.sql"
$vars = @(
  "\set admin_name '$(Esc $AdminName)'",
  "\set admin_login '$(Esc $AdminLogin)'",
  "\set admin_phone '$(Esc $AdminPhone)'"
) -join "`n"
[System.IO.File]::WriteAllText($varsFile, $vars + "`n",
                               (New-Object System.Text.UTF8Encoding $false))

try {
  & $psql -U $User -h $DbHost -d $Database -v ON_ERROR_STOP=1 `
          -f $varsFile `
          -f (Join-Path $dbDir 'new_superadmin.sql')
  $code = $LASTEXITCODE
} finally {
  Remove-Item $varsFile -ErrorAction SilentlyContinue
  $env:PGPASSWORD = $null
}

if ($code -ne 0) { throw "Создать суперадминистратора не удалось - см. выше." }

Write-Host "`nГотово. Вход: логин '$AdminLogin', пароль '0000'." -ForegroundColor Green
