# =============================================================================
# Одна команда, проверяющая проект целиком.
#
#   powershell -ExecutionPolicy Bypass -File check_all.ps1
#
# Что делает по шагам:
#   1. flutter analyze        - приложение
#   2. dart analyze           - бэкенд (отдельный пакет)
#   3. flutter test           - виджет-тесты и сценарии на моках
#   4. backend: юнит-тесты    - быстрые, без базы
#   5. backend: API-тесты     - на отдельной базе panorama_test
#   6. сверка схемы           - рабочая база против db/schema.sql
#
# Ключи:
#   -SkipDb    без PostgreSQL: пропускает шаги 5 и 6
#   -Fast      пропускает flutter test (самый долгий шаг)
#
# Важно: скрипт НЕ останавливается на первой ошибке. Он проходит все шаги и
# печатает сводку - иначе после каждой правки пришлось бы выяснять поломки по
# одной за прогон.
# =============================================================================
param(
  [switch]$SkipDb,
  [switch]$Fast,
  # Пароль суперпользователя postgres - нужен только для пересоздания
  # тестовой базы. Если не задан, run_tests.ps1 спросит его сам.
  [string]$SuperPassword
)

$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }

$steps = @()

function Invoke-Step {
  param([string]$Name, [string]$WorkDir, [scriptblock]$Body)

  Write-Host ""
  Write-Host ("=" * 78) -ForegroundColor DarkGray
  Write-Host "  $Name" -ForegroundColor Cyan
  Write-Host ("=" * 78) -ForegroundColor DarkGray

  Push-Location $WorkDir
  # ErrorActionPreference=Stop превращает любую строку stderr внешней программы
  # в исключение и обрывает прогон на первом же сообщении.
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Body
    $code = $LASTEXITCODE
  } catch {
    Write-Host $_ -ForegroundColor Red
    $code = 1
  } finally {
    $ErrorActionPreference = $prev
    Pop-Location
  }

  $ok = ($code -eq 0)
  Write-Host ("--> {0}" -f $(if ($ok) { 'OK' } else { "ОШИБКА (код $code)" })) `
    -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' })
  $script:steps += [pscustomobject]@{ Name = $Name; Ok = $ok; Skipped = $false }
}

function Skip-Step([string]$Name, [string]$Why) {
  Write-Host ""
  Write-Host "  $Name - пропущен: $Why" -ForegroundColor DarkYellow
  $script:steps += [pscustomobject]@{ Name = $Name; Ok = $true; Skipped = $true }
}

# --- 1. Анализ приложения ----------------------------------------------------
Invoke-Step 'flutter analyze (приложение)' $root { flutter analyze }

# --- 2. Анализ бэкенда -------------------------------------------------------
Invoke-Step 'dart analyze (бэкенд)' (Join-Path $root 'backend') { dart analyze }

# --- 3. Тесты приложения -----------------------------------------------------
if ($Fast) {
  Skip-Step 'flutter test' 'указан ключ -Fast'
} else {
  Invoke-Step 'flutter test (приложение)' $root { flutter test }
}

# --- 4-5. Тесты бэкенда ------------------------------------------------------
$runTests = Join-Path $root 'backend\run_tests.ps1'
if ($SkipDb) {
  Invoke-Step 'backend: юнит-тесты (без базы)' $root {
    powershell -ExecutionPolicy Bypass -File $runTests -UnitOnly
  }
  Skip-Step 'backend: API-тесты' 'указан ключ -SkipDb'
  Skip-Step 'сверка схемы с базой' 'указан ключ -SkipDb'
} else {
  Invoke-Step 'backend: все тесты (panorama_test)' $root {
    if ($SuperPassword) {
      powershell -ExecutionPolicy Bypass -File $runTests -SuperPassword $SuperPassword
    } else {
      powershell -ExecutionPolicy Bypass -File $runTests
    }
  }

  # --- 6. Сверка рабочей базы со схемой репозитория --------------------------
  Invoke-Step 'сверка рабочей базы со схемой' $root {
    powershell -ExecutionPolicy Bypass -File (Join-Path $root 'db\drift.ps1')
  }
}

# --- Сводка ------------------------------------------------------------------
Write-Host ""
Write-Host ("=" * 78) -ForegroundColor DarkGray
Write-Host "  ИТОГ" -ForegroundColor Cyan
Write-Host ("=" * 78) -ForegroundColor DarkGray

$failed = 0
foreach ($s in $steps) {
  if ($s.Skipped) {
    Write-Host ("  [ - ]  {0}" -f $s.Name) -ForegroundColor DarkYellow
  } elseif ($s.Ok) {
    Write-Host ("  [ OK]  {0}" -f $s.Name) -ForegroundColor Green
  } else {
    Write-Host ("  [FAIL] {0}" -f $s.Name) -ForegroundColor Red
    $failed++
  }
}

Write-Host ""
if ($failed -eq 0) {
  Write-Host "Всё зелёное." -ForegroundColor Green
  exit 0
}
Write-Host "Провалено шагов: $failed. Подробности выше." -ForegroundColor Red
exit 1
