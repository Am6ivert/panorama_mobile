# =============================================================================
# Общая часть для скриптов БД: найти psql.exe и настроить кодировку.
# Подключается через: . (Join-Path $PSScriptRoot '_psql.ps1')
# =============================================================================

function Find-Psql {
    # 1) реестр PostgreSQL
    try {
        $base = (Get-ItemProperty "HKLM:\SOFTWARE\PostgreSQL\Installations\*" -ErrorAction Stop |
                 Sort-Object PSChildName -Descending |
                 Select-Object -First 1).'Base Directory'
        if ($base) {
            $p = Join-Path $base 'bin\psql.exe'
            if (Test-Path $p) { return $p }
        }
    } catch {}

    # 2) PATH
    $cmd = Get-Command psql.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # 3) стандартные места установки - берём самую свежую версию
    $found = Get-ChildItem 'C:\Program Files\PostgreSQL\*\bin\psql.exe',
                           'C:\Program Files (x86)\PostgreSQL\*\bin\psql.exe' `
                           -ErrorAction SilentlyContinue |
             Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }

    throw @"
psql.exe не найден. Варианты:
  * PostgreSQL не установлен - поставьте:  winget install --id PostgreSQL.PostgreSQL.17 -e
  * установлен, но в другом месте - добавьте bin в PATH на эту сессию:
      `$env:Path += ';C:\Program Files\PostgreSQL\17\bin'
"@
}

# Все .sql-файлы проекта в UTF-8. Без этого psql на русской Windows читает их
# как WIN1251 и русские имена в seed.sql превращаются в мусор.
$env:PGCLIENTENCODING = 'UTF8'

# psql теперь отвечает в UTF-8, а PowerShell по умолчанию читает вывод внешних
# программ в кодировке консоли (cp866) - без этой строки русский текст от psql
# выглядит как "Р-Р?Р?РРР?Р?Р?Р".
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
