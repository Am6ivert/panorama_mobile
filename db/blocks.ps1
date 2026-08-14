# =============================================================================
# Что на самом деле создано: компании, объекты, блоки и квартиры в них.
# Ничего не меняет, только читает.
#
#   powershell -ExecutionPolicy Bypass -File "...\db\blocks.ps1"
#
# Вывод удобно сохранить в файл и прислать целиком:
#   powershell -ExecutionPolicy Bypass -File "...\db\blocks.ps1" > blocks.txt
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

& $psql -U $User -h $DbHost -d $Database -f (Join-Path $dbDir 'blocks.sql')

$env:PGPASSWORD = $null
