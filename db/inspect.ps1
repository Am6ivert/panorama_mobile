# =============================================================================
# Диагностика базы: что в ней есть на самом деле и чем она отличается от
# db\schema.sql. Ничего не меняет, только читает.
#
#   powershell -ExecutionPolicy Bypass -File "...\db\inspect.ps1"
#
# Вывод удобно сохранить в файл и прислать целиком:
#   powershell -ExecutionPolicy Bypass -File "...\db\inspect.ps1" > inspect.txt
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

& $psql -U $User -h $DbHost -d $Database -f (Join-Path $dbDir 'inspect.sql')

$env:PGPASSWORD = $null
