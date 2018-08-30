#!/bin/bash +x

ARGV=$@
WORK_PATH=$(pwd)
command_list=false
csp_need=false
openssl_need=false
git_need=false
gcc_need=false
zlib_need=false
pcre_need=false
nginx_need=false

# Пакеты будут скачены с "$url"
url="https://update.cryptopro.ru/support/nginx-gost"

revision_openssl="180423"
release_openssl="5.0.11216-5"
pcre_ver="pcre-8.42"
zlib_ver="zlib-1.2.11"

# Версия nginx для загрузки с github
nginx_branch="stable-1.14"

# Определение команд под систему
cat /etc/*release* | grep -Ei "(centos|red hat)" > /dev/null
if [ "$?" -eq 0 ] 
then
    apt="yum -y"
    pkgmsys="rpm"
    pkglist="rpm -qa"
    install="rpm -i"
    openssl_packages=(cprocsp-cpopenssl-110-base-${release_openssl}.noarch.rpm \
    cprocsp-cpopenssl-110-64-${release_openssl}.x86_64.rpm \
    cprocsp-cpopenssl-110-devel-${release_openssl}.noarch.rpm \
    cprocsp-cpopenssl-110-gost-64-${release_openssl}.x86_64.rpm)

    modules_path=/usr/lib64/nginx/modules
    cc_ld_opt=" --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector --param=ssp-buffer-size=4 -m64 -mtune=generic -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie'" 

else
    cat /etc/*release* | grep -Ei "(ubuntu|debian)" > /dev/null
    if [ "$?" -eq 0 ] 
    then
        apt="apt-get"
        pkgmsys="deb"
        pkglist="dpkg-query --list"
        install="dpkg -i"
        openssl_packages=(cprocsp-cpopenssl-110-base_${release_openssl}_all.deb \
        cprocsp-cpopenssl-110-64_${release_openssl}_amd64.deb \
        cprocsp-cpopenssl-110-devel_${release_openssl}_all.deb \
        cprocsp-cpopenssl-110-gost-64_${release_openssl}_amd64.deb)

        modules_path=/usr/lib/nginx/modules
        cc_ld_opt=" --with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'"
    else
        printf "Not supported system (supported: Ubuntu, Debian, CentOS, Red Hat).\n"
        exit 0
    fi
fi
# ----------------------------------------------


prefix=/etc/nginx
sbin_path=/usr/sbin/nginx
conf_path=/etc/nginx/nginx.conf
err_log_path=/var/log/nginx/error.log
http_log_path=/var/log/nginx/access.log
pid_path=/var/run/nginx.pid
lock_path=/var/run/nginx.lock
http_client_body_temp_path=/var/cache/nginx/client_temp
http_proxy_temp_path=/var/cache/nginx/proxy_temp
http_fastcgi_temp_path=/var/cache/nginx/fastcgi_temp
http_uwsgi_temp_path=/var/cache/nginx/uwsgi_temp
http_scgi_temp_path=/var/cache/nginx/scgi_temp
user=root
group=nginx


# Настройка установочной конфигурации nginx
nginx_paths=" --prefix=${prefix} --sbin-path=${sbin_path} --modules-path=${modules_path} --conf-path=${conf_path} --error-log-path=${err_log_path} --http-log-path=${http_log_path} --http-client-body-temp-path=${http_client_body_temp_path} --http-proxy-temp-path=${http_proxy_temp_path} --http-fastcgi-temp-path=${http_fastcgi_temp_path} --http-uwsgi-temp-path=${http_uwsgi_temp_path} --http-scgi-temp-path=${http_scgi_temp_path} --pid-path=${pid_path} --lock-path=${lock_path}"
nginx_parametrs=" --user=${user} --group=${group} --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module"
# Возможны и другие модули для которых требуется самостоятельная установка пакетов, например:
# --with-http_xslt_module=dynamic --with-http_image_filter_module=dynamic --with-http_geoip_module=dynamic
# --with-http_perl_module=dynamic
# ----------------------------------------------











# ----------------------------------------------
# -----------Проверка аргументов,---------------
# ------определение необходимых пакетов---------
# ----------------------------------------------

# Проверка аргументов и CSP
for arg_cur in ${ARGV};
do
    term="`echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $1}'`"
    define="`echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $2}'`"
    case ${term} in
        # Проверка CSP
        "--csp")
            csp_need=true
            csp=${define}
            ;;
    esac

    # Проверка command list
    if echo ${arg_cur}|grep "\-\-command_list" > /dev/null
    then
        command_list=true
    fi
    # Проверка force install
    if echo ${arg_cur}|grep "\-\-force_install" > /dev/null
    then
        openssl_need=true
        nginx_need=true
    fi
done

if [ ${csp_need} == false ] 
then
    if (eval "${pkglist} | grep cprocsp-base > /dev/null" && \
        eval "${pkglist} | grep cprocsp-capilite > /dev/null" && \
        eval "${pkglist} | grep cprocsp-kc1 > /dev/null" &&
        eval "${pkglist} | grep cprocsp-kc2 > /dev/null")
    then
        echo "CSP: found"
    else
        printf "CSP: not full installed. No argument --csp=[CSP_TGZ/CSP_DIR]\n"
        exit 0
    fi
fi
# ----------------------------------------------

# Проверка GCC
eval "$pkglist | grep -qw gcc > /dev/null"
if ! [ "$?" -eq 0 ]
then
    gcc_need=true
else
    echo "GCC: found"
fi
# ----------------------------------------------

# Проверка GIT
eval "$pkglist | grep \" git \" > /dev/null"
if ! [ "$?" -eq 0 ]
then
    git_need=true
else
    echo "GIT: found"
fi
# ----------------------------------------------

# Проверка openssl
if (eval "${pkglist} | grep cpopenssl-110-64 > /dev/null" && \
    eval "${pkglist} | grep cpopenssl-110-base > /dev/null" && \
    eval "${pkglist} | grep cpopenssl-110-devel > /dev/null" &&
    eval "${pkglist} | grep cpopenssl-110-gost-64 > /dev/null")
then
    echo "Openssl-1.1.0: found"
else
    openssl_need=true
fi
# ----------------------------------------------

# Проверка PCRE
if ! test -e "/usr/local/bin/pcre-config"
then
    pcre_need=true
else
    echo "PCRE: found"
fi
# ----------------------------------------------

# Проверка ZLIB
if ! test -e "/usr/local/lib/libz.so.1.2.11"
then
    zlib_need=true
else
    echo "ZLIB: found"
fi

# Провекра NGINX
if ! test -e "/usr/sbin/nginx"
then
    nginx_need=true
fi
# ----------------------------------------------

# ----------------------------------------------
# ----------------------------------------------
# ----------------------------------------------














# ----------------------------------------------
# ----------Вывод команд в файл-----------------
# ----------------------------------------------
if [ ${command_list} == true ];
then
    echo "Create command_list"
    printf "Command list:\n------------------------------\n\n" > command_list

    printf "wget --no-check-certificate -O nginx_conf.patch https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx_conf.patch\n\n" >> command_list
    printf "wget --no-check-certificate -O ${pcre_ver}.tar.gz ${url}/src/${pcre_ver}.tar.gz &&\n" >> command_list
    printf "wget --no-check-certificate -O ${zlib_ver}.tar.gz ${url}/src/${zlib_ver}.tar.gz\n\n" >> command_list

    for openssl_pkg in ${openssl_packages[@]}; 
    do 
        printf "wget --no-check-certificate -O $openssl_pkg ${url}/bin/${revision_openssl}/$openssl_pkg\n" >> command_list
    done
    printf "\ntar -xzvf ${pcre_ver}.tar.gz &&\n" >> command_list
    printf "tar -xzvf ${zlib_ver}.tar.gz\n\n" >> command_list
    if ! [ -d "$csp" ]
    then
        if ! [ -d csp ]
        then
            printf "mkdir csp\n" >> command_list
        fi
        printf "tar -xzvf $csp -C csp --strip-components 1\n\n" >> command_list
        csp="csp"
    fi
    printf "git clone https://github.com/nginx/nginx.git\n" >> command_list
    printf "cd nginx &&\n" >> command_list
    printf "git checkout branches/$nginx_branch\n\n" >> command_list

    if [ ${gcc_need} == true ];
    then
        printf "$apt install gcc\n" >> command_list
    fi

    if [ ${git_need} == true ];
    then
        printf "$apt install git\n\n" >> command_list
    fi

    if [ ${csp_need} == true ];
    then
        cmd=$install" lsb-cprocsp-kc2*"${pkgmsys}
        printf "cd ${csp} && ./install.sh && $cmd && cd ${WORK_PATH}\n" >> command_list
    fi

    if [ ${pcre_need} == true ];
    then
        printf "cd ${pcre_ver} && ./configure && make && make install && cd cd ${WORK_PATH}\n" >> command_list
    fi

    if [ ${zlib_need} == true ];
    then
        printf "${zlib_ver} && ./configure && make && make install && cd cd ${WORK_PATH}\n\n" >> command_list
    fi

    if [ ${openssl_need} == true ];
    then
        for openssl_pkg in ${openssl_packages[@]}; do
            cmd=$install" "$openssl_pkg
            printf "$cmd\n" >> command_list
        done
    fi

    cmd="./auto/configure${nginx_paths}${nginx_parametrs}${cc_ld_opt}"
    printf "\ncd ${WORK_PATH} && git apply nginx_conf.patch\n" >> command_list
    printf "cd nginx &&\n" >> command_list
    printf "$cmd &&\n" >> command_list
    printf "make && make install\n" >> command_list
    if ! [ -d /var/cache/nginx ]
    then
        printf "mkdir /var/cache/nginx" >> command_list
    fi

    exit 0
fi
# ----------------------------------------------
# ----------------------------------------------
# ----------------------------------------------










# Загрузка и распаковка пакетов
# Пакеты загружаются все возможные (не имеет значения нужны они или нет)
if ! [ -e "nginx_conf.patch" ]
then
    eval "wget --no-check-certificate -O nginx_conf.patch https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx_conf.patch" || exit 1
fi

if ! [ -e "${pcre_ver}.tar.gz" ]
then
    eval "wget --no-check-certificate -O ${pcre_ver}.tar.gz ${url}/src/${pcre_ver}.tar.gz" || exit 1
fi

if ! [ -e "${zlib_ver}.tar.gz" ]
then
    eval "wget --no-check-certificate -O ${zlib_ver}.tar.gz ${url}/src/${zlib_ver}.tar.gz" || exit 1
fi

for openssl_pkg in ${openssl_packages[@]}; 
do 
    if ! [ -e "$openssl_pkg" ]
    then
        eval "wget --no-check-certificate -O $openssl_pkg ${url}/bin/${revision_openssl}/$openssl_pkg" || exit 1; 
    fi
done

if ! [ -d "$pcre_ver" ]
then
    eval "tar -xzvf ${pcre_ver}.tar.gz" || exit 1
fi

if ! [ -d "$zlib_ver" ]
then
    eval "tar -xzvf ${zlib_ver}.tar.gz" || exit 1
fi

if (! test -d "$csp" && test "$csp_need" == "true")
then
    if ! [ -d csp ]
    then
        mkdir csp
    fi
    tar -xzvf $csp -C csp --strip-components 1 || exit 1
    csp="csp"
fi

if ! [ -d "nginx" ]
then
    echo "Clone nginx repository"
    git clone https://github.com/nginx/nginx.git || exit 1
    cd nginx || exit 1
    echo "Switch branch"
    git checkout branches/$nginx_branch || exit 1
fi
cd ${WORK_PATH}
# ----------------------------------

# Инсталяция пакетов
# Инсталируются только необходимые пакеты, которые не нашлись в системе
if [ ${gcc_need} == true ];
then
    echo "Install gcc"
    eval "$apt install gcc" || exit 1
fi

if [ ${git_need} == true ];
then
    echo "Install git"
    eval "$apt install git" || exit 1
fi

if [ ${csp_need} == true ];
then
    echo "Install CSP"
    cmd=$install" lsb-cprocsp-kc2*"${pkgmsys}
    cd ${csp} && ./install.sh && eval "$cmd" && cd ${WORK_PATH} || exit 1
fi

if [ ${pcre_need} == true ];
then
    echo "Install PCRE"
    cd ${pcre_ver} && ./configure && make && make install && cd ${WORK_PATH} || exit 1
fi

if [ ${zlib_need} == true ];
then
    echo "Install ZLIB" 
    cd ${zlib_ver} && ./configure && make && make install && cd ${WORK_PATH} || exit 1
fi

if [ ${openssl_need} == true ];
then
    echo "Install Openssl-1.1.0"
    for openssl_pkg in ${openssl_packages[@]}; do
        cmd=$install" "$openssl_pkg
        eval "$cmd" || exit 1
    done
fi

# ----------------------------------

# Установка nginx
if [ ${nginx_need} == true ];
then
    echo "Apply patch"
    cd ${WORK_PATH} && cp nginx_conf.patch ./nginx/nginx_conf.patch  || exit 1
    cd nginx && git apply nginx_conf.patch || exit 1
    
    cmd="./auto/configure${nginx_paths}${nginx_parametrs}${cc_ld_opt}"
    echo "Nginx: configure and install"
    eval $cmd && make && make install || exit 1
    echo "NGINX: installed"
else
    echo "NGINX: installed"
fi

if ! [ -d /var/cache/nginx ]
then
    mkdir /var/cache/nginx
fi
cd ${WORK_PATH}
# ----------------------------------
