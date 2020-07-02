# Nginx-gost
Скрипты для установки nginx с поддержкой GOST и RSA cipher suites (nginx + openssl gostengy + cryptopro csp).  
Инструкция по установке и обсуждение на форуме: https://www.cryptopro.ru/forum2/default.aspx?g=posts&t=12505

## Usage
Самый простой путь для инсталяции nginx:
```
sudo ./install-nginx.sh --csp=/path_to_csp_dir/or/path_to_csp_tgz/
sudo ./install-certs.sh
```

## Scripts
### install-nginx.sh
Устанавливает **nginx** для работы с **rsa** и **gost** сертификатами. Если на системе нет каких-либо пакетов (openssl-1.1.0, csp, zlib и пр.), будет произведена их инсталяция.

- **\-\-csp=[csp]**  
Указание архива или директории с пакетами csp. В случае отсутствия установленного csp, этот параметр является **обязательным**.
- **\-\-install=[pkg]**  
Force инсталяция пакета (даже если пакет уже установлен). Поддерживаемые pkg: git, gcc, zlib, pcre, csp, openssl, nginx.
- **\-\-noinstall=[pkg]**  
Игнорирование инсталяции пакета (в этом случае, могут возникнуть проблемы при установке nginx). Поддерживаемые pkg: git, gcc, zlib, pcre.
- **\-\-command_list**  
Запись в файл *command_list.txt* списка команд для конкретной системы, которые будут выполнены при установке nginx.
- **\-\-help**  
Справка по командам.

*Замечание*: если **\-\-csp** не указан, на системе должны быть установлены пакеты csp как kc1, так и kc2. На Ubuntu, например, сделать это можно так:
```
cd /path_to_csp_dir/
sudo ./install
sudo dpkg -i lsb-cprocsp-kc2-64_4.0.0-5_amd64.deb
```

### install-certs.sh
 Генерация и установка **rsa** и **gost** сертификатов, настройка соответствующей конфигурации **nginx**.  Гостовый сертификат будет установлен в контейнер "ngxtest".
 
- **\-\-certname=NAME**  
Выбор имени для сертификатов (по умолчанию "srvtest.pem" для GOST и "srvtestRSA.pem" для RSA).
- **\-\-container=NAME**  
Выбор контейнера для GOST сертификата (по умолчанию "ngxtest").
