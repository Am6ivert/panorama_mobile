# =============================================================================
# Проверка изоляции данных: токены, роли, доступ к чужим сущностям.
# Запуск (сервер должен быть уже поднят). Путь - полный, из любой папки:
#   powershell -ExecutionPolicy Bypass -File "D:\works\panorama\Новая папка\panorama_mobile\backend\smoke_auth.ps1"
#
# С проверкой ролей и изоляции компаний (подставьте СВОИ логины, без скобок):
#   ... -MgrLogin azamat -Org2Login elit.admin
# =============================================================================
param(
  [string]$BaseUrl    = 'http://localhost:8080/api/v1',
  [string]$AdminLogin = 'admin',
  [string]$AdminPass  = '0000',
  [string]$MgrLogin   = '',
  [string]$MgrPass    = '0000',
  # Администратор ВТОРОЙ компании - для проверки изоляции данных.
  [string]$Org2Login  = '',
  [string]$Org2Pass   = '0000'
)

$ok = 0; $fail = 0

function Check($name, $expected, $scriptblock) {
  $status = & $scriptblock
  if ($status -eq $expected) {
    Write-Host ("  [OK]   {0} -> {1}" -f $name, $status) -ForegroundColor Green
    $script:ok++
  } else {
    Write-Host ("  [FAIL] {0} -> {1}, ожидалось {2}" -f $name, $status, $expected) -ForegroundColor Red
    $script:fail++
  }
}

function Status($method, $path, $token, $body) {
  $headers = @{}
  if ($token) { $headers['Authorization'] = "Bearer $token" }
  try {
    $p = @{ Uri = "$BaseUrl$path"; Method = $method; Headers = $headers }
    if ($body) { $p['Body'] = ($body | ConvertTo-Json); $p['ContentType'] = 'application/json' }
    (Invoke-WebRequest @p -UseBasicParsing).StatusCode
  } catch {
    if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { -1 }
  }
}

function Login($login, $pass) {
  try {
    $r = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post `
         -ContentType 'application/json' `
         -Body (@{ login = $login; password = $pass } | ConvertTo-Json)
    $r.token
  } catch { $null }
}

Write-Host "`n== 1. Без токена всё закрыто ==" -ForegroundColor Cyan
Check 'GET  /health   (публично)'  200 { Status GET  '/health'        $null $null }
Check 'GET  /units    (без токена)' 401 { Status GET  '/units'         $null $null }
Check 'GET  /clients  (без токена)' 401 { Status GET  '/clients'       $null $null }
Check 'POST /users    (без токена)' 401 { Status POST '/users'         $null @{ name = 'x' } }
Check 'GET  /units    (мусорный токен)' 401 { Status GET '/units' 'deadbeef' $null }

Write-Host "`n== 2. Вход администратора ==" -ForegroundColor Cyan
$adminToken = Login $AdminLogin $AdminPass
if (-not $adminToken) {
  Write-Host "  Не удалось войти как '$AdminLogin'. Укажи -AdminLogin/-AdminPass." -ForegroundColor Yellow
  exit 1
}
Write-Host "  токен получен ($($adminToken.Length) симв.)" -ForegroundColor Gray
Check 'GET /auth/me   (админ)' 200 { Status GET '/auth/me' $adminToken $null }
Check 'GET /audit     (админ)' 200 { Status GET '/audit'   $adminToken $null }
Check 'GET /clients   (админ)' 200 { Status GET '/clients' $adminToken $null }

Write-Host "`n== 3. Токен в БД хранится только хешем ==" -ForegroundColor Cyan
Write-Host "  Проверь вручную - открытого токена в таблице быть не должно:" -ForegroundColor Gray
Write-Host "    psql -U panorama -d panorama -c ""SELECT left(token_hash,16), length(token_hash) FROM sessions ORDER BY created_at DESC LIMIT 3""" -ForegroundColor Gray
Write-Host "  Ожидаем 64 символа hex (SHA-256), а не 48 (исходный токен)." -ForegroundColor Gray

if ($MgrLogin) {
  Write-Host "`n== 4. Менеджеру закрыты админские действия ==" -ForegroundColor Cyan
  $mgrToken = Login $MgrLogin $MgrPass
  if (-not $mgrToken) {
    Write-Host "  Не удалось войти как '$MgrLogin'." -ForegroundColor Yellow
  } else {
    Check 'GET  /audit    (менеджер)' 403 { Status GET  '/audit'      $mgrToken $null }
    Check 'POST /users    (менеджер)' 403 { Status POST '/users'      $mgrToken @{ name = 'x'; login = 'x'; phone = '1' } }
    Check 'POST /complexes(менеджер)' 403 { Status POST '/complexes'  $mgrToken @{ name = 'x'; address = 'y' } }
    Check 'GET  /clients  (менеджер)' 200 { Status GET  '/clients'    $mgrToken $null }

    Write-Host "`n== 5. Выход отзывает токен ==" -ForegroundColor Cyan
    Check 'POST /auth/logout'          200 { Status POST '/auth/logout' $mgrToken $null }
    Check 'GET  /units (после выхода)' 401 { Status GET  '/units'       $mgrToken $null }
  }
} else {
  Write-Host "`n== 4-5. Пропущено ==" -ForegroundColor Yellow
  Write-Host "  Передай -MgrLogin <логин менеджера>, чтобы проверить ограничения роли." -ForegroundColor Gray
}

if ($Org2Login) {
  Write-Host "`n== 6. Изоляция между компаниями ==" -ForegroundColor Cyan
  $org2Token = Login $Org2Login $Org2Pass
  if (-not $org2Token) {
    Write-Host "  Не удалось войти как '$Org2Login'." -ForegroundColor Yellow
  } else {
    function Get-Json($path, $token) {
      try {
        Invoke-RestMethod -Uri "$BaseUrl$path" -Headers @{ Authorization = "Bearer $token" }
      } catch { $null }
    }

    $units1 = @(Get-Json '/units' $adminToken)
    $units2 = @(Get-Json '/units' $org2Token)
    $users1 = @(Get-Json '/users' $adminToken)
    $users2 = @(Get-Json '/users' $org2Token)

    Write-Host ("  компания 1: квартир {0}, сотрудников {1}" -f $units1.Count, $users1.Count) -ForegroundColor Gray
    Write-Host ("  компания 2: квартир {0}, сотрудников {1}" -f $units2.Count, $users2.Count) -ForegroundColor Gray

    $unitOverlap = @($units1.id | Where-Object { $units2.id -contains $_ }).Count
    $userOverlap = @($users1.id | Where-Object { $users2.id -contains $_ }).Count
    Check 'фонд компаний не пересекается'       0 { $unitOverlap }
    Check 'сотрудники компаний не пересекаются' 0 { $userOverlap }

    if ($units1.Count -gt 0) {
      $foreignUnit = $units1[0].id
      Check 'чужая квартира: смена статуса' 409 {
        Status POST "/units/$foreignUnit/status" $org2Token @{ status = 'off_market' } }
      Check 'чужая квартира: правка карточки' 404 {
        Status POST "/units/$foreignUnit" $org2Token @{ rooms = 1; area = 40; status = 'free' } }
      Check 'чужая квартира: взять в работу' 409 {
        Status POST "/units/$foreignUnit/take" $org2Token @{} }
      Check 'чужая квартира: снять бронь' 403 {
        Status POST "/units/$foreignUnit/release" $org2Token @{} }
    } else {
      Write-Host "  У компании 1 нет квартир - проверка по объекту пропущена." -ForegroundColor Yellow
    }

    if ($users1.Count -gt 0) {
      $foreignUser = ($users1 | Where-Object { $_.login -ne $AdminLogin } | Select-Object -First 1).id
      if ($foreignUser) {
        Check 'чужой сотрудник: блокировка' 404 {
          Status POST "/users/$foreignUser/block" $org2Token @{ blocked = $true } }
        Check 'чужой сотрудник: смена роли' 404 {
          Status POST "/users/$foreignUser/role" $org2Token @{ role = 'admin' } }
        Check 'чужой сотрудник: смена пароля' 404 {
          Status POST "/users/$foreignUser/password" $org2Token @{ new_password = 'hacked' } }
      }
    }
  }
} else {
  Write-Host "`n== 6. Пропущено ==" -ForegroundColor Yellow
  Write-Host "  Заведите вторую компанию через db\new_org.sql и передайте" -ForegroundColor Gray
  Write-Host "  -Org2Login <логин её админа>, чтобы проверить изоляцию данных." -ForegroundColor Gray
}

Write-Host "`n== Итог: успешно $ok, провалено $fail ==" -ForegroundColor $(if ($fail) { 'Red' } else { 'Green' })
exit $(if ($fail) { 1 } else { 0 })
