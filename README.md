# PSConnectivityCheck

## Описание

Инструмент проверки сетевой связанности элементов контура на уровне портов и протоколов. Позволяет выявлять проблемы с подключением и конфигурацией сетевых устройств, а также генерировать отчеты о готовности окружения к работе.

## Проверки

- Доступность удаленного порта
- Соответствие протокола заданному
- Корректность работы HTTPS
- Корректность работы DNS

## Требования к среде исполнения

- PowerShell 6, лучше 7 и выше
  - Windows 2012 R2 и выше
  - AltLinux p8 лучше p10 и выше
  - MacOS 10.15 и выше ( в режиме разработки )
  - Powershell Module `powershell-yaml`. [Описание](yaml/readme.md)

## Архитектура

![architecture](architecture.png)
[architecture](architecture.excalidraw)

## Структура проекта

```powershell
.
├── yaml  # папка с yaml модулями
├── architecture.excalidraw  # схема архитектуры
├── PSConnectivityCheck.ps1  # основной скрипт
├── EnvironmentConnectivityExample.yaml  # пример конфигурации окружения
├── ReportExample.yaml  # пример отчета
```

## Установка и использование

```powershell
git clone https://github.com/msklv/PSConnectivityCheck.git
cd PSConnectivityCheck
.\PSConnectivityCheck.ps1 -EnvironmentConfigFilePath .\EnvironmentConnectivityExample.yaml
```

## Пример конфигурации окружения

```yaml
```
