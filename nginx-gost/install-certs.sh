#!/bin/bash -x

ARGV=$@
certname='srvtest'

# Проверка аргументов
for arg_cur in ${ARGV};
do
    term="`echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $1}'`"
    define="`echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $2}'`"
    case ${term} in
        # Указание имени сертификата
        "--certname")
            certname=${define}
            ;;
    esac
done

/opt/cprocsp/bin/amd64/certmgr -list | grep 'HDIMAGE\\\\ngxtest'

if [ $? -eq 0 ]
then
	/opt/cprocsp/bin/amd64/certmgr -delete -container '\\.\HDIMAGE\ngxtest'
fi

# Генерация тестового сертефиката:
/opt/cprocsp/bin/amd64/cryptcp -creatcert -provtype 81 -provname 'Crypto-Pro GOST R 34.10-2012 KC1 Strong CSP' -rdn "CN=${certname}" -cont "\\\\.\\HDIMAGE\\ngxtest" -certusage 1.3.6.1.5.5.7.3.1 -ku -du -ex -ca http://cryptopro.ru/certsrv

# Смена KC1 на KC2 в имени провайдера, так как nginx работает с провайдером KC2:
/opt/cprocsp/bin/amd64/certmgr -inst -store uMy -cont '\\.\HDIMAGE\ngxtest' -provtype 75 -provname "Crypto-Pro GOST R 34.10-2001 KC2 CSP" || exit 1

# Экспорт сертификата:
/opt/cprocsp/bin/amd64/certmgr -export -cert -dn "CN=${certname}" -dest "/etc/nginx/${certname}.cer" || exit 1

# Смена кодировкии сертификата DER на PEM:
openssl x509 -inform DER -in "/etc/nginx/${certname}.cer" -out "/etc/nginx/${certname}.pem" || exit 1

# Генерация сертификатов RSA:
openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/${certname}RSA.key -nodes -out /etc/nginx/${certname}RSA.pem -subj '/CN=${certname}RSA/C=RU' || exit 1
openssl rsa -in /etc/nginx/${certname}RSA.key -out /etc/nginx/${certname}RSA.key

# Загрузка файла конфигурации:
wget --no-check-certificate "https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx.conf" || exit 1

# Установка конфигурации nginx:
sed -r "s/srvtest/${certname}/g" nginx.conf > nginx_tmp.conf
rm nginx.conf
mv ./nginx_tmp.conf /etc/nginx/nginx.conf || exit 1
