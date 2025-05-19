# Кроссплатформенный скрипт проверки сетевой связанности

## Алгоритм работы
# - Выбор режима работы (Markdown или Allure)
# - Чтение файла конфигурации окружения
# - Поиск тестов по Имени хоста или Алиасам
# - Разрешение DNS имен в Тестах
# - Выполнение проверок в сл. порядке:
#   - PORT - Открытость порта, любой протокол
#   - HTTP - Проверка протокола HTTP и кода ответа из диапазона 2xx или 3xx
#   - HTTPS - Проверка протокола HTTPS, валидация сертификата и кода ответа из диапазона 2xx или 3xx ( будет добавлено позже )
# -  Формирование отчета в формате Markdown или Allure

param(
  [Parameter(Mandatory = $false)]
  [ValidateNotNullOrEmpty()]
  [string]$EnvironmentConfigFilePath = ".\EnvironmentConnectivity.yaml",

  [Parameter(Mandatory = $false)]
  [ValidateSet("Allure", "Markdown")]
  [string]$ReportType = "Allure"  # Для тестов!, по умолчанию для обратной совместимости должен быть Markdown

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

# Чтение файла конфигурации с проверкой соответствия формату конвертацией YAML
try {
  $global:envConfig = Get-Content -Path $EnvironmentConfigFilePath -Raw -ErrorAction Stop | ConvertFrom-Yaml
}
catch {
  Write-Host "Error: Не удалось прочитать файл конфигурации $($EnvironmentConfigFilePath)!" -ForegroundColor "Red"
  Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
  exit 1 # Выходим с ошибкой
}


# _____________________________ Переменные и константы _____________________________

$global:startTime = Get-Date      # Время начала выполнения скрипта
$global:localHostName = [System.Environment]::MachineName.ToString()        # Имя хоста
$global:currentUserName = [System.Environment]::UserName.ToString()         # Текущий пользователь
$global:supportTestTypes = @("port", "http", "https")                       # Поддерживаемые типы тестов
$global:tcpTimeoutInMs = 2000                                               # Таймаут TCP соединения в миллисекундах


$global:markdownReportName = "ConnectCheck_$($global:localHostName)_$($global:startTime.ToString("yyyyMMdd_HHmmss")).md" # Имя файла отчета
$global:markdownReportFilePath = ".\$($global:markdownReportName)"                  # Путь к файлу отчета

# _____________________________ Объекты  _____________________________
class AllureReport {
  # https://allurereport.org/docs/how-it-works-test-result-file/
  [string]$uuid             # Уникальный идентификатор запуска теста
  [string]$name             # Название
  #[string]$fullName         # Полное название теста
  [string]$historyId        # Идентификатор для группировки тестов
  [string]$description      # Описание в формате Markdown
  [array]$links = @()       # Ссылки на внешние ресурсы
  [array]$labels = @()      # Метаданные
  [string]$status           # Possible values are: “failed”, “broken”, “passed”, “skipped”, “unknown”
  #[string]$parameters       # Параметры
  #[string]$stage            # Possible values are: “scheduled”, “running”, “finished”, “pending”, “interrupted”.
  [string]$start            # Время начала
  [string]$stop             # Время окончания 
  [array]$steps = @()

  # Конструктор класса
  AllureReport() {
    $this.name = "Connectivity Check Report"
    $this.historyId = $this.name
    $this.uuid = ([guid]::NewGuid().ToString())
    $this.status = $false
    $this.steps = @()
  }

  [void]AddStep(
    [string]$name, 
    [bool]$passed,
    [DateTime]$startTime,
    [DateTime]$endTime,
    [string]$message,
    [string]$category
  ) {
    $this.Status = $passed
    # duration в секундах
    $duration = ($endTime - $startTime)

    $logs = @{
      "message" = $message
      "level"   = "INFO"
    }

    $step = @{
      name      = $name
      id        = $category + " / " + $name 
      passed    = $passed
      startTime = $startTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
      endTime   = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
      duration  = $duration.TotalSeconds
      logs      = $logs
      category  = $category
    }

    $this.Steps += $step  # добавляем шаг в список

    if (-not $passed) {
      # Фейлим общий результат, если хотя бы один шаг не прошел.
      $this.Status = $false
    }
  }

  [string] ExportToJson() {
    return $this | ConvertTo-Json -Depth 10
  }
}

# ________________________________ Отчет Markdown ________________________________________

# Создание файла отчета
try {
  $global:reportFile = New-Item -Path $global:markdownReportFilePath -ItemType File -Force
}
catch {
  Write-Host "Error: Не удалось создать файл отчета $($global:markdownReportFilePath)!" -ForegroundColor "Red"
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
- Connection Timeout: **$($global:tcpTimeoutInMs) ms**
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
  Add-Content -Path $global:markdownReportFilePath -Value $ReportMessage

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
  Add-Content -Path $global:markdownReportFilePath -Value $ReportMessage

  # Вывод в консоль
  Write-Host $ReportMessage -ForegroundColor DarkGray

}




# ___________________________________ Функции ______________________________________

# Преобразование DateTime в Unix Timestamp
function Convert-ToUnixTimestamp {
    param (
        [Parameter(Mandatory = $true)]
        [DateTime]$DateTime,

        [ValidateSet("Seconds", "Milliseconds")]
        [string]$Precision = "Seconds"
    )

    $dto = [DateTimeOffset]::new($DateTime.ToUniversalTime())

    switch ($Precision) {
        "Seconds"      { return $dto.ToUnixTimeSeconds() }
        "Milliseconds" { return $dto.ToUnixTimeMilliseconds() }
    }
}

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
  #exit 0

}


# Отбор необходимого теста по имени хоста
function selectTestsByHost {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$envConfig            # Полная конфигурация окружения
  )

  $tests = @()

  # Сопоставляем по главному имени хоста
  if ($envConfig.ContainsKey($localHostName)) {
    if ($envConfig."$localHostName".ContainsKey("services")) {
      $tests = $envConfig."$localHostName".services
      addTextPart2Report -text "Тест сопоставлен по главному имени $localHostName"
      return $tests
    }
    else {
      addTextPart2Report -text "## Что то не то с конфигурацией окружения"
      finishReport -text "Хост $localHostName найден, но ключ *.services* не найден."
    }
  }


  # Сопоставляем по алиасам, перебираем хосты с ними
  foreach ($configHost in $envConfig.Keys) {
    if ($envConfig."$configHost".ContainsKey("alias")) {
      # Перебираем алиасы
      foreach ($alias in $envConfig."$configHost".alias) {
        if ($alias -eq $localHostName) {
          if ($envConfig."$configHost".ContainsKey("services")) {
            $tests = $envConfig."$configHost".services
            addTextPart2Report -text "Тест сопоставлен по алиасу $alias для хоста $configHost" > $null
            return $tests
          }
          else {
            addTextPart2Report -text "## Что то не то с конфигурацией окружения"
            finishReport -text "Конфигурация $configHost найдена, алиас $alias совпадает с хостом $localHostName, но ключ *.services* не найден."
          }
        }
      }
    }
    
  }

  # Отдаем дефолтные тесты, если они есть.
  if ($envConfig.ContainsKey("_default_")) {
    if ($envConfig._default_.ContainsKey("services")) {
      $tests = $envConfig._default_.services
      addTextPart2Report -text "Выбран **_default_** тест"
      return $tests
    }
    else {
      addTextPart2Report -text "## Что то не то с конфигурацией окружения"
      finishReport -text "_default_ конфигурация найдена для $localHostName, но ключ *.services* не найден."
    }
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
        if ($task.Wait($global:tcpTimeoutInMs)) {
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
            $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec $($global:tcpTimeoutInMs / 1000)
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
            $response = Invoke-WebRequest -Uri $url -Method Get -TimeoutSec $($global:tcpTimeoutInMs / 1000)
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

# ________________________________  Режимы работы _____________________________________

function MarkdownMode {

  # Запись заголовка отчета в MD
  addTextPart2Report -text $reportHeader > $null

  # Поиск тестов по Имени хоста или Алиасам
  $ConnectTests = selectTestsByHost -envConfig $envConfig

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

}

function AllureMode {

  # Поиск тестов по Имени хоста или Алиасам
  $ConnectTests = selectTestsByHost -envConfig $envConfig

  # Создание объекта отчета
  $AllureReport = [AllureReport]::new()


  # Разрешение всех DNS Имен в Тестах


  # Проверка открытых портов


  # Проверка по http протоколу


  # Проверка по https протоколу


  # Запись отчета

} 


# ______________________________ Маршрутизатор _______________________________


if ($ReportType -eq "Markdown") {
  MarkdownMode > $null
}


if ($ReportType -eq "Allure") {
  AllureMode > $null
}

