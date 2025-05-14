# Connectivity Check Report

- Host: **MacBook-Pro-M1-Michael**
- User: **mihailsokolov**
- Date: **2025-05-14 12:13:40**
- Environment Configuration: **.\EnvironmentConnectivity.yaml**
- Connection Timeout: **2000 ms**

Выбран **_default_** тест

## Тесты

```shell
http:
- petstore.swagger.io:
  - 80
  - 443
  - 8080
- hostName: 8080
pg:
- clusterName.local: 5432
port:
- 10.0.0.4:
  - 111
  - 444
- hostName: 222
https:
- github.com: 443
- huggingface.co:
  - 444
  - 80
  - 443
```

## Разрешение DNS имен

- DNS: github.com, -> IP: 20.207.73.82

- DNS: hostName, -> IP: Error

- DNS: huggingface.co, -> IP: 2600:9000:2576:2800:17:b174:6d00:93a1, 2600:9000:2576:f000:17:b174:6d00:93a1, 2600:9000:2576:c600:17:b174:6d00:93a1, 2600:9000:2576:7a00:17:b174:6d00:93a1, 2600:9000:2576:5200:17:b174:6d00:93a1, 2600:9000:2576:bc00:17:b174:6d00:93a1, 2600:9000:2576:2c00:17:b174:6d00:93a1, 2600:9000:2576:7400:17:b174:6d00:93a1, 18.161.125.68, 18.161.125.84, 18.161.125.127, 18.161.125.35

- DNS: petstore.swagger.io, -> IP: 35.170.130.168, 54.84.209.3

## Проверки по TCP портам

- Host: 10.0.0.4 TCP Port: 111, Status: Closed (таймаут)

- Host: 10.0.0.4 TCP Port: 444, Status: Closed (таймаут)

- Host: hostName TCP Port: 222, Status: Closed (исключение: Exception calling "Wait" with "1" argument(s): "One or more errors occurred. (nodename nor servname provided, or not known)")

## Проверки по http

- HTTP: http://petstore.swagger.io:80, Status: OK (код: 200)

- HTTP: http://petstore.swagger.io:443, Status: Error (исключение: Response status code does not indicate success: 400 (Bad Request).)

- HTTP: http://petstore.swagger.io:8080, Status: Error (исключение: The request was canceled due to the configured HttpClient.Timeout of 2 seconds elapsing.)

- HTTP: http://hostName:8080, Status: Error (исключение: nodename nor servname provided, or not known (hostname:8080))

## Проверки по https

- HTTPS: https://github.com:443, Status: OK (код: 200)

- HTTPS: https://huggingface.co:444, Status: Error (исключение: The request was canceled due to the configured HttpClient.Timeout of 2 seconds elapsing.)

- HTTPS: https://huggingface.co:80, Status: Error (исключение: The SSL connection could not be established, see inner exception.)

- HTTPS: https://huggingface.co:443, Status: OK (код: 200)

## Отчет завершен в 05/14/2025 12:13:55

