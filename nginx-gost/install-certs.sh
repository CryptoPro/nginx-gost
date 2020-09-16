#!/bin/bash -x 

ARGV=$@
install_root=0
mod=""
certname='srvtest'
container='ngxtest'
provtype='81' #75, 80, 81
provnameKC1='Crypto-Pro GOST R 34.10-2012 KC1 Strong CSP'
#Crypto-Pro GOST R 34.10-2001 KC1 CSP
#Crypto-Pro GOST R 34.10-2012 KC1 CSP
#Crypto-Pro GOST R 34.10-2012 KC1 Strong CSP
provnameKC2='Crypto-Pro GOST R 34.10-2012 KC2 Strong CSP'
#Crypto-Pro GOST R 34.10-2001 KC2 CSP
#Crypto-Pro GOST R 34.10-2012 KC2 CSP
#Crypto-Pro GOST R 34.10-2012 KC2 Strong CSP
ca_url='http://testgost2012.cryptopro.ru/certsrv'



#Проверка аргументов
for arg_cur in ${ARGV};
do
    term="`echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $1}'`"
    define="`echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $2}'`"

    if test "$term" == ""; then
        term="`echo ${arg_cur}|awk '/^\-\-.+/{print $1}'`"
    fi

    case ${term} in
        # Указание имени сертификата
        "--certname")
            certname=${define}
            ;;
        "--container")
            container=${define}
            ;;
        "--silent")
            install_root=1
            mod="-silent"
            ;;
    esac
done

/opt/cprocsp/bin/amd64/certmgr -list -store uMy | grep "CN=${certname}"
if [ $? -eq 0 ]
then
    /opt/cprocsp/bin/amd64/certmgr -delete -store uMy -dn CN=${certname}
fi

/opt/cprocsp/bin/amd64/csptest -enum -info -type PP_ENUMCONTAINERS | grep "${container}"
if [ $? -eq 0 ]
then
    /opt/cprocsp/bin/amd64/csptest -keyset -deletekeyset -provtype ${provtype} -container ${container}
fi

if [ $install_root -eq 1 ]
then
    # Установка root-сертификата
    wget --no-check-certificate -O test_ca_root.cer "${ca_url}/certnew.cer?ReqID=CACert&Renewal=1&Enc=bin"
    /opt/cprocsp/bin/amd64/certmgr -install -file test_ca_root.cer -store mroot -silent
fi

# Генерация тестового сертефиката:
/opt/cprocsp/bin/amd64/cryptcp -creatcert -provtype ${provtype} -provname "${provnameKC1}" ${mod} -rdn "CN=${certname}" -cont "\\\\.\\HDIMAGE\\${container}" -certusage 1.3.6.1.5.5.7.3.1 -ku -du -ex -ca ${ca_url} || exit 1

# Смена KC1 на KC2 в имени провайдера, так как nginx работает с провайдером KC2:
/opt/cprocsp/bin/amd64/certmgr -inst -store uMy -cont "\\\\.\\HDIMAGE\\${container}" -provtype ${provtype} -provname "${provnameKC2}" || exit 1

# Экспорт сертификата:
/opt/cprocsp/bin/amd64/certmgr -export -store uMy -cert -dn "CN=${certname}" -dest "/etc/nginx/${certname}.cer" || exit 1

# Смена кодировкии сертификата DER на PEM:
openssl x509 -inform DER -in "/etc/nginx/${certname}.cer" -out "/etc/nginx/${certname}.pem" || exit 1

# Генерация сертификатов RSA:
openssl req -x509 -newkey rsa:2048 -keyout /etc/nginx/${certname}RSA.key -nodes -out /etc/nginx/${certname}RSA.pem -subj "/CN=${certname}RSA/C=RU" || exit 1
openssl rsa -in /etc/nginx/${certname}RSA.key -out /etc/nginx/${certname}RSA.key

# Загрузка файла конфигурации:
wget --no-check-certificate "https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx.conf" || exit 1

# Установка конфигурации nginx:
sed -r "s/srvtest/${certname}/g" nginx.conf > nginx_tmp.conf
rm nginx.conf
mv ./nginx_tmp.conf /etc/nginx/nginx.conf || exit 1
