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
$global:reportFilePath = ".\$($global:reportName)" # Путь к файлу отчета

# ________________________________ Отчет ________________________________________
# Создание файла отчета
try {
    $global:reportFile = New-Item -Path $global:reportFilePath -ItemType File -Force
} catch {
    Write-Host "Error: Не удалось создать файл отчета $($global:reportFilePath)!" -ForegroundColor "Red"
    Write-Host "  ${($_.Exception.Message)}" -ForegroundColor DarkGray
    exit 1 # Выходим с ошибкой
}

# Запись заголовка в файл отчета
$reportHeader = @"
# ConnectCheck Report

### Host: $($global:localHostName)
### User: $($global:currentUserName)
### Date: $($global:startTime.ToString("yyyy-MM-dd HH:mm:ss"))
### Environment Configuration: $($EnvironmentConfigFilePath)

"@

# Дозапись данных в файл отчета - Форматированный текст


# Дозапись данных в файл отчета - Исходный Код


# ___________________________________ Функции ______________________________________





# ___________