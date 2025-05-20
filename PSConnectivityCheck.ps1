# Кроссплатформенный скрипт проверки сетевой связанности

## Алгоритм работы
#- Чтение файла конфигурации
#- Поиск тестов по Имени хоста или Алиасам
#- Сборка итоговых тестов из сервисов
#- Разрешение DNS имен в Тестах
#- Выполнение проверок в сл. порядке:
#  - PORT - Открытость порта, любой протокол
#  - HTTP - Проверка протокола HTTP и кода ответа из диапазона 2xx или 3xx
#  - HTTPS - Проверка протокола HTTPS, валидация сертификата и кода ответа из диапазона 2xx или 3xx ( будет добавлено позже )
#- Формирование отчета в формате Markdown  

param(
  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$EnvironmentConfigFilePath = ".\EnvironmentConnectivity.yaml"
)



# _________________________________ Проверки _____________________________________

# Проверка версии Powershell
if ($PSVersionTable.PSVersion.Major -lt 6) {
  Write-Host "Error: Для работы утилиты необходим Powershell версии 6 и выше" -ForegroundColor "Red"
  exit 1 # Выходим с ошибкой
}

# Проверка на необходимые модули Powershell для работы утилиты
try {
  import-module powershell-yaml -ErrorAction:Stop
}
catch {
  Write-Host "Error: Модуль powershell-yaml не найден!" -ForegroundColor "Red"
  Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
  exit 1 # Выходим с ошибкой
}

# Проверка на наличие файла конфигурации
if (-not (Test-Path -Path $EnvironmentConfigFilePath -PathType Leaf)) {
  Write-Host "Error: Файл конфигурации $EnvironmentConfigFilePath не найден!" -ForegroundColor "Red"
  exit 1 # Выходим с ошибкой
}

# Чтение файла конфигурации и преобразование в объект
try {
  $envConfig = Get-Content -Path $EnvironmentConfigFilePath -Raw -ErrorAction Stop | ConvertFrom-Yaml
}
catch {
  Write-Host "Error: Не удалось прочитать файл конфигурации $($EnvironmentConfigFilePath)!" -ForegroundColor "Red"
  Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
  exit 1 # Выходим с ошибкой
}

# Возможно стоит проверить наличие всех используемых сервисов в конфигурации.


# _____________________________ Переменные и константы _____________________________

$global:startTime = Get-Date      # Время начала выполнения скрипта
$global:localHostName = [System.Environment]::MachineName.ToString()      # Имя хоста
$global:currentUserName = [System.Environment]::UserName.ToString()         # Текущий пользователь
$global:reportName = "ConnectCheck_$($global:localHostName)_$($global:startTime.ToString("yyyyMMdd_HHmmss")).md" # Имя файла отчета
$global:reportFilePath = ".\$($global:reportName)"                         # Путь к файлу отчета
$global:supportTestTypes = @("port", "http", "https")                        # Поддерживаемые типы тестов
$global:tcpTimeout = 2000                                              # Таймаут TCP соединения в миллисекундах


# ________________________________ Отчет ________________________________________

# Создание файла отчета
try {
  $global:reportFile = New-Item -Path $global:reportFilePath -ItemType File -Force
}
catch {
  Write-Host "Error: Не удалось создать файл отчета $($global:reportFilePath)!" -ForegroundColor "Red"
  Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
  exit 1 # Выходим с ошибкой
}

# Заголовок отчета
$reportHeader = @"
# Connectivity Check Report

- Host: **$($global:localHostName)**
- User: **$($global:currentUserName)**
- Date: **$($global:startTime.ToString("yyyy-MM-dd HH:mm:ss"))**
- Environment Configuration: **$($EnvironmentConfigFilePath)**
- Connection Timeout: **$($global:tcpTimeout) ms**
"@

# Дозапись данных в файл отчета - Форматированный текст
function addTextPart2Report {
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$text
  )

  #Создание текстового блока
  $Text = $Text.Trim()
  $ReportMessage = @"
$Text

"@
  
  # Запись в файл отчета
  Add-Content -Path $global:reportFilePath -Value $ReportMessage

  # Вывод в консоль
  Write-Host $ReportMessage -ForegroundColor DarkGray

}

# Дозапись данных в файл отчета - Исходный Код
function addShellPart2Report {
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$shell
  )

  #Создание текстового блока
  $shell = $shell.Trim()
  $ReportMessage = @" 
``````shell
$shell
``````

"@

  # Запись в файл отчета
  Add-Content -Path $global:reportFilePath -Value $ReportMessage

  # Вывод в консоль
  Write-Host $ReportMessage -ForegroundColor DarkGray

}




# ___________________________________ Функции ______________________________________

# Завершение отчета
function finishReport {
  param (
    [Parameter(Mandatory = $false)]
    [string]$text
  )
  
  # Стандарт
  addTextPart2Report -text "## Отчет завершен в $(Get-Date)" > $null
  
  # Доп текст
  if ($text) {
    addTextPart2Report -text $text > $null
  }

  # Выход из скрипта
  exit 0

}

# Подготовка конфигурации по главному имени хоста
# Возврат - конфигурация тестов
function prepareConfigByHostName {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$envConfig,            # Полная конфигурация тестирования сетевой связанности

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$HostName             # Имя хоста
  )

  $tests = @()   # Массив элементов для теста

  # Проверяем наличие ключа Хоста
  if (-not ($envConfig.ContainsKey($HostName))) {
    return $tests
  }

  # Проверяем наличие ключа services
  if ($envConfig."$HostName".ContainsKey("services")) {
    # Берем блок services
    $tests += $envConfig."$HostName".services
    # Перебираем тесты
    addTextPart2Report -text "Тест сопоставлен по  имени $HostName, добавлен блок services $($tests.Count) элементов" > $null
  }


  # Добавляем тесты из блока serviceGroups
  if ($envConfig."$HostName".ContainsKey("serviceGroups")) {
    foreach ($serviceGroupName in $envConfig."$HostName".serviceGroups.Keys) {
      # Проверяем наличие ключа _serviceGroups_
      if ( -not ($envConfig.ContainsKey("_serviceGroups_"))) {
        addTextPart2Report -text "## Что то не то с конфигурацией тестирования"
        finishReport -text "Блок _serviceGroups_ не найден в конфигурации."
      }
      # Проверяем наличие ключа serviceGroupName
      if ($envConfig._serviceGroups_.ContainsKey($serviceGroupName)) {
        # Непосредственно добавляем тесты из блока serviceGroups
        $tests += $envConfig._serviceGroups_."$serviceGroupName"
        addTextPart2Report -text "Тест сопоставлен по  имени $HostName, добавлен блок serviceGroups, итого $($tests.Count) элементов" > $null
      }
      else {
        addTextPart2Report -text "## Что то не то с конфигурацией тестирования"
        finishReport -text "Конфигурация _serviceGroups_ найдена, но сервис группа $serviceGroupName не найдена."
      }
    }
  }
  


  # Возвращаем найденные тесты или пустой массив
  return $tests

}


# Отбор необходимого теста по имени хоста
function selectConnectivityTests {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$envConfig            # Полная конфигурация окружения
  )

  $tests = @()

  # Сопоставляем по главному имени хоста
  $tests = prepareConfigByHostName -envConfig $envConfig -HostName $localHostName
  if ($tests) { return $tests } # Если тесты найдены, то возвращаем их


  # Сопоставляем по алиасам, перебираем хосты с ними
  # Перебираем все хосты в конфигурации
  foreach ($configHost in $envConfig.Keys) {
    if (-not ($envConfig."$configHost".ContainsKey("alias"))) {
      continue # Если алиасов нет, то пропускаем
    }

    # Перебираем алиасы для обрабатываемого хоста
    foreach ($alias in $envConfig."$configHost".alias) {
      if ($alias -eq $localHostName) {
          addTextPart2Report -text "Тест сопоставлен по алиасу $alias для хоста $configHost" > $null
          $tests = prepareConfigByHostName -envConfig $envConfig -HostName $configHost
          if ($tests) { return $tests } # Если тесты найдены, то возвращаем их
      }
    }
    
  }



  # Отдаем дефолтные тесты, если они есть.
  if ($envConfig.ContainsKey("_default_")) {
    $tests = prepareConfigByHostName -envConfig $envConfig -HostName "_default_"
    addTextPart2Report -text "Выбран **_default_** тест"
    if ($tests) { return $tests } # Если тесты найдены, то возвращаем их
  }



  # Если тестов нет, то записываем в отчет этот факт
  addTextPart2Report -text "## Что то не то с конфигурацией окружения"
  finishReport -text "Ничего не удалось сопоставить с данным хостом $localHostName."
 
}


# Разрешаем все DNS имена
function resolveAllDNSNames {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$ConnectTests            # Полная конфигурация окружения
  )

  addTextPart2Report -text "## Разрешение DNS имен" > $null

  $dnsNames = @()

  # Перебираем типы тестов и получаем все DNS имена
  foreach ($testName in $global:supportTestTypes) {
    if ($ConnectTests.ContainsKey($testName)) {
      foreach ($test in $ConnectTests.$testName) {
        $dnsNames += $test.Keys
      }
      
    }
  }

  # Удаляем дубликаты DNS имен
  $dnsNames = $dnsNames | Sort-Object -Unique

  # Удаляем IP адреса v4
  $dnsNames = $dnsNames | Where-Object { $_ -notmatch '^\d+\.\d+\.\d+\.\d+$' }
  # Удаляем IP адреса v6
  #$dnsNames = $dnsNames | Where-Object { $_ -notmatch '^::ffff:\d+\.\d+\.\d+\.\d+$' }

  # Перебираем DNS имена
  foreach ($dnsName in $dnsNames) {
    # Разрешение
    try {
      $resolveIPs = ([System.Net.Dns]::Resolve($dnsName)).AddressList.IPAddressToString -join ", "
      addTextPart2Report -text "- DNS: $dnsName, -> IP: $resolveIPs" > $null
    }
    catch {
      addTextPart2Report -text "- DNS: $dnsName, -> IP: Error" > $null
    }

  }

}


# Проверки открытых портов
function checkOpenPorts {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$ConnectTests            # Полная конфигурация окружения
  )

  addTextPart2Report -text "## Проверки по TCP портам" > $null

  $testElements = @()   # Массив элементов для теста

  if ($ConnectTests.ContainsKey("port")) {
    # Превращаем тесты в список
    foreach ($testElement in $ConnectTests.port) {
      foreach ($values in $testElement.Values) {
        # Поочереди добавляем в массив
        foreach ($value in $values) {
          $testElements += "$($testElement.Keys)" + ":" + "$value"
        }  
      }
    }
    # Перебираем тесты
    foreach ($testElement in $testElements) {
      # Разделяем на хост и порт
      $HostName, $port = $testElement -split ":"
      
      # Проверяем доступность порта
      try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $task = $tcpClient.ConnectAsync($HostName, $port)
        if ($task.Wait($global:tcpTimeout)) {
          if ($task.IsFaulted) {
            addTextPart2Report -text "- Host: $HostName TCP Port: $port, Status: Closed (ошибка подключения)" > $null
          }
          else {
            addTextPart2Report -text "- Host: $HostName TCP Port: $port, Status: Open" > $null
          }
        }
        else {
          addTextPart2Report -text "- Host: $HostName TCP Port: $port, Status: Closed (таймаут)" > $null
        }
      }
      catch {
        addTextPart2Report -text "- Host: $HostName TCP Port: $port, Status: Closed (исключение: $($_.Exception.Message))" > $null
      }
      finally {
        if ($tcpClient) { $tcpClient.Close() }
      }
    }


  }
  else {
    addTextPart2Report -text "Нет элементов типа __port__" > $null
  }
  
}

# Проверки по http
function checkHTTP {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$ConnectTests            # Полная конфигурация окружения
  )

  addTextPart2Report -text "## Проверки по http" > $null

  if ($ConnectTests.ContainsKey("http")) {
    foreach ($testElement in $ConnectTests.http) {
      foreach ($values in $testElement.Values) {
        foreach ($value in $values) {
          $url = "http://" + "$($testElement.Keys)" + ":" + "$value"
          try {
            $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec $($global:tcpTimeout / 1000)
            # Проверяем код ответа 2xx или 3xx - успешный
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
              addTextPart2Report -text "- HTTP: $url, Status: OK (код: $($response.StatusCode))" > $null
            }
            else {
              addTextPart2Report -text "- HTTP: $url, Status: Failed (код: $($response.StatusCode))" > $null
            }
          }
          catch {
            addTextPart2Report -text "- HTTP: $url, Status: Error (исключение: $($_.Exception.Message))" > $null
          }
        }
      }
    }
  }
  else {
    addTextPart2Report -text "Нет элементов типа __http__" > $null
  }
}

# Проверки по https
function checkHTTPS {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$ConnectTests            # Полная конфигурация окружения
  )

  addTextPart2Report -text "## Проверки по https" > $null

  if ($ConnectTests.ContainsKey("https")) {
    foreach ($testElement in $ConnectTests.https) {
      foreach ($values in $testElement.Values) {
        foreach ($value in $values) {
          $url = "https://" + "$($testElement.Keys)" + ":" + "$value"
          try {
            $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec $($global:tcpTimeout / 1000)
            # Проверяем код ответа 2xx или 3xx - успешный
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
              addTextPart2Report -text "- HTTPS: $url, Status: OK (код: $($response.StatusCode))" > $null
            }
            else {
              addTextPart2Report -text "- HTTPS: $url, Status: Failed (код: $($response.StatusCode))" > $null
            }
          }
          catch {
            addTextPart2Report -text "- HTTPS: $url, Status: Error (исключение: $($_.Exception.Message))" > $null
          }
        }
      }
    }
  }
  else {
    addTextPart2Report -text "Нет элементов типа __https__" > $null
  }

}


# ______________________________ Основная логика _______________________________


# Запись заголовка отчета
addTextPart2Report -text $reportHeader > $null


# Поиск тестов по Имени хоста или Алиасам
$ConnectTests = selectConnectivityTests -envConfig $envConfig

# Найдены тесты
addTextPart2Report -text "## Тесты" > $null
$ConnectTestsString = $ConnectTests | ConvertTo-Yaml
addShellPart2Report -shell "$ConnectTestsString" > $null



# Разрешение всех DNS Имен в Тестах
resolveAllDNSNames -ConnectTests $ConnectTests > $null


# Проверка открытых портов
checkOpenPorts -ConnectTests $ConnectTests > $null


# Проверка по http протоколу
checkHTTP -ConnectTests $ConnectTests > $null


# Проверка по https протоколу
checkHTTPS -ConnectTests $ConnectTests > $null


# Завершение отчета
finishReport > $null
