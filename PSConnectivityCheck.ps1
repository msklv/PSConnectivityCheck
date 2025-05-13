# Скрипт проверки сетевой связанности

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


# ___________________________________ Функции ______________________________________