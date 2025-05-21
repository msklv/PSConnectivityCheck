# Импорт модуля Pester
Import-Module Pester

## Тестирование PSConnectivityCheck.ps1 с помощью Pester
BeforeAll {

    ## Импортируем PSConnectivityCheck.ps1
    . "$PSScriptRoot/PSConnectivityCheck.ps1" -EnvironmentConfigFilePath "no.json"

    #Универсальный способ добавления
    #$PSCommandPath.Replace('.Tests.ps1','.ps1')

}



Describe "mergeTestConfigs" {

    It "Объединяет два конфига с разными ключами" {
        $config1 = @{ port = @(@{server1 = 80}) }
        $config2 = @{ http = @(@{server2 = 8080}) }
        $result = mergeTestConfigs -config1 $config1 -config2 $config2

        $result.Keys | Should -Contain "port"
        $result.Keys | Should -Contain "http"
        $result.port.Count | Should -Be 1
        $result.http.Count | Should -Be 1
    }

    It "Объединяет два конфига с одинаковыми ключами (слияние массивов)" {
        $config1 = @{ port = @(@{server1 = 80}) }
        $config2 = @{ port = @(@{server2 = 443}) }
        $result = mergeTestConfigs -config1 $config1 -config2 $config2

        $result.Keys.Count | Should -Be 1
        $result.port.Count | Should -Be 2
        $result.port | Should -Contain @{server1=80}
        $result.port | Should -Contain @{server2=443}
    }

    It "Оставляет только ключи из supportTestTypes" {
        $global:supportTestTypes = @("port", "http")
        $config1 = @{ port = @(@{a=1}); notsupported = @(@{b=2}) }
        $config2 = @{ http = @(@{c=3}) }
        $result = mergeTestConfigs -config1 $config1 -config2 $config2

        $result.Keys | Should -Contain "port"
        $result.Keys | Should -Contain "http"
        $result.Keys | Should -NotContain "notsupported"
    }
}


# Предполагается, что функция prepareConfigByHostName уже импортирована в сессию

Describe "prepareConfigByHostName" {

    $baseConfig = @{
        "host1" = @{
            services = @{
                port = @(@{server1 = 80})
                http = @(@{server1 = 8080})
            }
            serviceGroups = @{
                groupA = $true
            }
        }
        "_serviceGroups_" = @{
            groupA = @{
                port = @(@{server2 = 443})
            }
        }
        "_default_" = @{
            services = @{
                port = @(@{server3 = 22})
            }
        }
    }

    It "Возвращает тесты по основному имени хоста (только services)" {
        $result = prepareConfigByHostName -envConfig $baseConfig -HostName "host1"
        $result.Keys | Should -Contain "port"
        $result.Keys | Should -Contain "http"
        $result.port | Should -Contain @{server1=80}
        $result.http | Should -Contain @{server1=8080}
    }

    It "Добавляет тесты из serviceGroups" {
        $result = prepareConfigByHostName -envConfig $baseConfig -HostName "host1"
        $result.port | Where-Object { $_.server2 -eq 443 } | Should -NotBeNullOrEmpty
    }

    It "Возвращает пустую хеш-таблицу если хост не найден" {
        $result = prepareConfigByHostName -envConfig $baseConfig -HostName "unknownhost"
        $result.Keys.Count | Should -Be 0
    }

    It "Возвращает _default_ если указан _default_" {
        $result = prepareConfigByHostName -envConfig $baseConfig -HostName "_default_"
        $result.port | Should -Contain @{server3=22}
    }
}