# =============================================================================
# Create the Panorama database from scratch on a new machine.
#
# Prerequisites:
#   1. PostgreSQL 18 installed (https://www.postgresql.org/download/windows/).
#      Remember the 'postgres' superuser password set during install.
#   2. The project checked out (git clone / git pull) - SQL files live in db\.
#
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File db\setup.ps1
#
# The script asks for the 'postgres' superuser password (only to create the
# role and database - it is not stored) and creates:
#     * role      panorama (password panorama)
#     * database  panorama (with schema and demo data)
#
# WARNING: init.sql recreates the 'panorama' database from scratch (DROP + CREATE).
# Re-running is safe, but all data in that database is wiped.
#
# NOTE: keep this file ASCII-only. Windows PowerShell 5.1 reads .ps1 as ANSI
# (cp1251) and mangles UTF-8 Cyrillic, which breaks string literals.
# =============================================================================
$ErrorActionPreference = 'Stop'
$dbDir = $PSScriptRoot
if (-not $dbDir) { $dbDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# The .sql files are UTF-8. Tell psql so, otherwise it assumes the Windows
# console codepage (e.g. WIN1251) and fails on multi-byte UTF-8 sequences.
$env:PGCLIENTENCODING = 'UTF8'

function Fail($msg) { $env:PGPASSWORD = $null; Write-Host "`nERROR: $msg" -ForegroundColor Red; exit 1 }

# --- 0. Make sure the SQL files are present ----------------------------------
foreach ($f in 'init.sql','schema.sql','seed.sql') {
    if (-not (Test-Path (Join-Path $dbDir $f))) {
        Fail "db\$f not found. Run the script from the project root (is the repo checked out fully?)."
    }
}

# --- 1. Find psql.exe --------------------------------------------------------
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
    Fail "psql.exe not found. Install PostgreSQL, or set the path to psql.exe at the top of this script."
}
Write-Host "psql: $psql" -ForegroundColor Cyan

# --- 2. Superuser password (you type it) -------------------------------------
$sec = Read-Host "Password for superuser 'postgres'" -AsSecureString
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $sec).Password

# --- 3. Check the connection BEFORE running the scripts ----------------------
Write-Host "`nChecking connection to the server..." -ForegroundColor Green
& $psql -U postgres -h localhost -v ON_ERROR_STOP=1 -c "SELECT 1;" *> $null
if ($LASTEXITCODE -ne 0) {
    Fail @"
could not connect to PostgreSQL on localhost:5432.
Possible causes:
  * the PostgreSQL service is not running (Win+R -> services.msc -> PostgreSQL -> Start);
  * wrong 'postgres' superuser password;
  * PostgreSQL is listening on a different port.
"@
}

# --- 4. Role + database (recreated) + pgcrypto extension ---------------------
Write-Host "[1/3] Role, database (recreated), pgcrypto extension..." -ForegroundColor Green
& $psql -U postgres -h localhost -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'init.sql')
if ($LASTEXITCODE -ne 0) { Fail "init.sql failed (wrong postgres password?)." }

# From here on - as the application role.
$env:PGPASSWORD = 'panorama'

Write-Host "`n[2/3] Schema (tables, indexes)..." -ForegroundColor Green
& $psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'schema.sql')
if ($LASTEXITCODE -ne 0) { Fail "schema.sql failed." }

Write-Host "`n[3/3] Seed data..." -ForegroundColor Green
& $psql -U panorama -h localhost -d panorama -v ON_ERROR_STOP=1 -f (Join-Path $dbDir 'seed.sql')
if ($LASTEXITCODE -ne 0) { Fail "seed.sql failed." }

# --- 5. Verification ---------------------------------------------------------
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
& $psql -U panorama -h localhost -d panorama -c "SELECT count(*) AS apartments FROM apartments;"
& $psql -U panorama -h localhost -d panorama -c "SELECT login, full_name FROM users ORDER BY login;"

$env:PGPASSWORD = $null
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host "Done. Database 'panorama', role 'panorama' (password 'panorama')." -ForegroundColor Green
Write-Host "Demo accounts log in with password 0000." -ForegroundColor Green
Write-Host "`nStart the server:  cd backend  ->  dart run bin\server.dart" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
