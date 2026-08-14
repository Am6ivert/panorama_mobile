# =============================================================================
# Сверка живой базы с тем, что описано в репозитории (db\schema.sql).
# Показывает любые правки, сделанные мимо репозитория: лишние и недостающие
# таблицы, колонки, различия в NOT NULL, DEFAULT и типах.
#
#   powershell -ExecutionPolicy Bypass -File "...\db\drift.ps1"
#
# Ничего не меняет, только читает. Если все пять разделов пусты - расхождений
# нет. Файл db\drift.sql сгенерирован из schema.sql, руками его не правят:
# после изменения схемы попросите пересобрать эталон.
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

$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
& $psql -U $User -h $DbHost -d $Database -v ON_ERROR_STOP=1 `
        -f (Join-Path $dbDir 'drift.sql')
$code = $LASTEXITCODE
$ErrorActionPreference = $prev

$env:PGPASSWORD = $null
# Ненулевой код = найдены расхождения. Нужен, чтобы шаг ловился check_all.ps1.
exit $code
