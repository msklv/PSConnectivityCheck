# Модуль YAML для PowerShell

- [PowerShell YAML Module](https://www.powershellgallery.com/packages/powershell-yaml/)

## offline установка модуля

- [Linux](doc-install-ps-module-nix.md)
- [Windows](doc-install-ps-module-win.md)

## Установка модуля YAML при помощи PowerShell Gallery

```powershell
# Установка
Install-Module -Name powershell-yaml -Force
# Проверка установки
Get-Module -ListAvailable -Name powershell-yaml
Get-Command -Module powershell-yaml
```

## Используемые версии

- powershell-yaml.0.4.12.nupkg - Windows, Linux и разработка
- powershell-yaml.0.4.8-rc2.nupkg - Alt8 c PowerShell 6, проверить совместимость
