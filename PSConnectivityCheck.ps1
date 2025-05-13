# Кроссплатформенный скрипт проверки сетевой связанности

## Алгоритм работы
#- Поиск тестов по Имени хоста или Алиасам
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
} catch {
    Write-Host "Error: Модуль powershell-yaml не найден!" -ForegroundColor "Red"
	Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
    exit 1 # Выходим с ошибкой
}

# Проверка на наличие файла конфигурации
if (-not (Test-Path -Path $EnvironmentConfigFilePath -PathType Leaf)) {
	Write-Host "Error: Файл конфигурации $EnvironmentConfigFilePath не найден!" -ForegroundColor "Red"
	exit 1 # Выходим с ошибкой
}


# _____________________________ Переменные и константы _____________________________

$global:startTime       = Get-Date      # Время начала выполнения скрипта
$global:localHostName   = [System.Environment]::MachineName.ToString()      # Имя хоста
$global:currentUserName = [System.Environment]::UserName.ToString()         # Текущий пользователь
$global:reportName      = "ConnectCheck_$($global:localHostName)_$($global:startTime.ToString("yyyyMMdd_HHmmss")).md" # Имя файла отчета
$global:reportFilePath  = ".\$($global:reportName)"                         # Путь к файлу отчета


# ________________________________ Отчет ________________________________________

# Создание файла отчета
try {
    $global:reportFile = New-Item -Path $global:reportFilePath -ItemType File -Force
} catch {
    Write-Host "Error: Не удалось создать файл отчета $($global:reportFilePath)!" -ForegroundColor "Red"
    Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
    exit 1 # Выходим с ошибкой
}

# Заголовок отчета
$reportHeader = "
# Connectivity Check Report

### Host: $($global:localHostName)
### User: $($global:currentUserName)
### Date: $($global:startTime.ToString("yyyy-MM-dd HH:mm:ss"))
### Environment Configuration: $($EnvironmentConfigFilePath)
"

# Дозапись данных в файл отчета - Форматированный текст
function addTextPart2Report {
  param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Text
  )

  #Создание текстового блока
  $Text = $Text.Trim()
  $ReportMessage = "
  $Text

  "
  
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
  $ReportMessage = " 
  ```shell
  $shell
  ```

  "

  # Запись в файл отчета
  Add-Content -Path $global:reportFilePath -Value $ReportMessage

  # Вывод в консоль
  Write-Host $ReportMessage -ForegroundColor DarkGray

}




# ___________________________________ Функции ______________________________________

function selectTestsByHost {
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [object]$envConfig            # Полная конфигурация окружения
  )

  $tests = @()

  # Сопоставляем по главному имени хоста

  # Сопоставляем по алиасам


  # Отдаем дефолтные тесты, если они есть.



  # Если тестов нет, то записываем в отчет этот факт
 
}

# ______________________________ Основная логика _______________________________

# Чтение файла конфигурации
try {
    $envConfig = Get-Content -Path $EnvironmentConfigFilePath -Raw -ErrorAction Stop | ConvertFrom-Yaml
} catch {
    Write-Host "Error: Не удалось прочитать файл конфигурации $($EnvironmentConfigFilePath)!" -ForegroundColor "Red"
    Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
    exit 1 # Выходим с ошибкой
}


# Запись заголовка отчета
addTextPart2Report -Text $reportHeader > $null


# Возможно стоит проверить конфигурацию на валидность


# Поиск тестов по Имени хоста или Алиасам
$ConnectTests = selectTestsByHost -envConfig $envConfig
# Для тестирования, Начало
$ConnectTests = @"
services:
  port:
    - 10.0.0.4:
        - 111
        - 444
    - hostName: 222
  pg:
    - clusterName.local:5432
  http:
    - 10.0.0.3:80
    - hostName: 8080
  https:
    - 10.0.0.4:443  
"@
$ConnectTests = $ConnectTests | ConvertFrom-Yaml
# Для тестирования, Конец

