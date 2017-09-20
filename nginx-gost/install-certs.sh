#!/bin/bash -x

# Генерация тестового сертефиката:
/opt/cprocsp/bin/amd64/cryptcp -creatcert -provtype 81 -provname 'Crypto-Pro GOST R 34.10-2012 KC1 Strong CSP' -rdn 'CN=srvtest' -cont '\\.\HDIMAGE\srvtest' -certusage 1.3.6.1.5.5.7.3.1 -ku -du -ex -ca http://cryptopro.ru/certsrv

# Смена KC1 на KC2 в имени провайдера, так как nginx работает с провайдером KC2:
/opt/cprocsp/bin/amd64/certmgr -inst -store uMy -cont '\\.\HDIMAGE\srvtest' -provtype 75 -provname "Crypto-Pro GOST R 34.10-2001 KC2 CSP" || exit 1

# Экспорт сертификата:
/opt/cprocsp/bin/amd64/certmgr -export -cert -dn "CN=srvtest" -dest '/etc/nginx/srvtest.cer' || exit 1

# Смена кодировкии сертификата DER на PEM:
openssl x509 -inform DER -in "/etc/nginx/srvtest.cer" -out "/etc/nginx/srvtest.pem" || exit 1

# Генерация сертификатов RSA:
openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/srvtestRSA.key -nodes -out /etc/nginx/srvtestRSA.pem -subj '/CN=srvtestRSA/C=RU' || exit 1
openssl rsa -in /etc/nginx/srvtestRSA.key -out /etc/nginx/srvtestRSA.key

# Загрузка файла конфигурации:
wget "https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx.conf" || exit 1

# Установка конфигурации nginx:
mv ./nginx.conf /etc/nginx/nginx.conf || exit 1