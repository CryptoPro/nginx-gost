#!/bin/bash +x

ARGV=($@)
WORK_PATH=$(pwd)

# Пакеты будут скачены с "$url"
url="https://update.cryptopro.ru/support/nginx-gost"

revision_openssl="211453"
release_openssl="5.0.11803-6"
pcre_ver="pcre-8.44"
zlib_ver="zlib-1.2.11"

# Версия nginx для загрузки с github
nginx_branch="stable-1.16"

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
command_list=false
git_need=""
gcc_need=""
zlib_need=""
pcre_need=""

openssl_need=""
nginx_need=""
csp_need=""
csp=""

# Проверка аргументов и CSP
for arg_cur in "${ARGV[@]}"
do
    term="$(echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $1}')"
    define="$(echo ${arg_cur}|awk -F= '/^\-\-.+=.+/{print $2}')"
    if test "${term}" != ""
    then
        case ${term} in
            # Проверка CSP
            "--csp")
                csp=${define}
                ;;
            "--install")
                # git
                if test "${define}" == "git"
                then
                    git_need=true
                    
                # gcc
                elif test "${define}" == "gcc"
                then
                    gcc_need=true

                # zlib
                elif test "${define}" == "zlib"
                then
                    zlib_need=true

                # pcre
                elif test "${define}" == "pcre"
                then
                    pcre_need=true

                # csp
                elif test "${define}" == "csp"
                then
                    csp_need=true

                # openssl
                elif test "${define}" == "openssl"
                then
                    openssl_need=true

                # nginx
                elif test "${define}" == "nginx"
                then
                    nginx_need=true
                
                else
                    echo "Bad value for \"${term}\": ${define}"
                    exit 1
                fi
                ;;
            "--noinstall")
                # git
                if test "${define}" == "git"
                then
                    git_need=false
                    
                # gcc
                elif test "${define}" == "gcc"
                then
                    gcc_need=false

                # zlib
                elif test "${define}" == "zlib"
                then
                    zlib_need=false

                # pcre
                elif test "${define}" == "pcre"
                then
                    pcre_need=false
                
                else
                    echo "Bad value for \"${term}\": ${define}"
                    exit 1
                fi
                ;;
            *)
                echo "Bad arg: ${term}"
                exit 1
                ;;
        esac

    # Проверка command list
    elif echo "${arg_cur}" | grep "\-\-command_list" > /dev/null
    then
        command_list=true

    # Вывод справки
    elif echo "${arg_cur}" | grep "\-\-help" > /dev/null
    then
        echo "Usage: ./install-nginx.sh <option>"
        echo ""
        echo "Option:"
        echo "--command_list               Print all commands to a file \"command_list.txt\""
        echo "                             without executing them."
        echo "--csp=[csp]                  Path to CSP (tgz or dir)."
        echo "--noinstall=[pkg]            Ignore check and skip install package."
        echo "                             Pkg: gcc, git, pcre, zlib."
        echo "--install=[pkg]              Force install package."
        echo "                             Pkg: gcc, git, pcre, zlib"
        echo "                                  csp, openssl, nginx."
        echo "--help                       Print this help."
        exit 0

    # Не верные аргументы
    else
        echo "Bad arg: ${arg_cur}"
        exit 1 
    fi
done

if test "${csp_need}" == ""
then
    if (eval "${pkglist} | grep cprocsp-base > /dev/null" && \
        eval "${pkglist} | grep cprocsp-capilite > /dev/null" && \
        eval "${pkglist} | grep cprocsp-kc1 > /dev/null" &&
        eval "${pkglist} | grep cprocsp-kc2 > /dev/null")
    then
        echo "CSP: found"
        csp_need=false
    else
        echo "CSP: not full installed"
        if test "${csp}" == ""
        then
            printf "No argument --csp=[CSP_TGZ/CSP_DIR]\n"
            exit 0
        fi
        csp_need=true
    fi
else
    if test ${csp_need} == true
    then
        echo "CSP: force install"
        if test "${csp}" == ""
        then
            printf "No argument --csp=[CSP_TGZ/CSP_DIR]\n"
            exit 0
        fi
    else
        echo "CSP: force noinstall"
    fi
fi
# ----------------------------------------------

# Проверка GCC
if test "${gcc_need}" == ""
then
    eval "$pkglist | grep -qw gcc > /dev/null"
    if ! test "$?" -eq 0
    then
        echo "GCC: not found (will be installed)"
        gcc_need=true
    else
        echo "GCC: found"
        gcc_need=false
    fi
else
    if test ${gcc_need} == true
    then
        echo "GCC: force install"
    else
        echo "GCC: force noinstall"
    fi
fi
# ----------------------------------------------

# Проверка GIT
if test "${git_need}" == ""
then
    eval "$pkglist | grep \" git \" > /dev/null"
    if ! test "$?" -eq 0
    then
        echo "GIT: not found (will be installed)"
        git_need=true
    else
        echo "GIT: found"
        git_need=false
    fi
else
    if test ${git_need} == true
    then
        echo "GIT: force install"
    else
        echo "GIT: force noinstall"
    fi
fi
# ----------------------------------------------

# Проверка Openssl-1.1.0
if test "${openssl_need}" == ""
then
    if (eval "${pkglist} | grep cpopenssl-110-64 > /dev/null" && \
        eval "${pkglist} | grep cpopenssl-110-base > /dev/null" && \
        eval "${pkglist} | grep cpopenssl-110-devel > /dev/null" &&
        eval "${pkglist} | grep cpopenssl-110-gost-64 > /dev/null")
    then
        echo "Openssl-1.1.0: found"
        openssl_need=false
    else
        echo "Openssl-1.1.0: not found (will be installed)"
        openssl_need=true
    fi
else
    if test ${openssl_need} == true
    then
        echo "Openssl-1.1.0: force install"
    else
        echo "Openssl-1.1.0: force noinstall"
    fi
fi
# ----------------------------------------------

# Проверка PCRE
if test "${pcre_need}" == ""
then
    if ! test -e "/usr/local/bin/pcre-config"
    then
        echo "PCRE: not found (will be installed)"
        pcre_need=true
    else
        echo "PCRE: found"
        pcre_need=false
    fi
else
    if test ${pcre_need} == true
    then
        echo "PCRE: force install"
    else
        echo "PCRE: force noinstall"
    fi
fi
# ----------------------------------------------

# Проверка ZLIB
if test "${zlib_need}" == ""
then
    if ! test -e "/usr/local/lib/libz.so.1.2.11"
    then
        echo "ZLIB: not found (will be installed)"
        zlib_need=true
    else
        echo "ZLIB: found"
        zlib_need=false
    fi
else
    if test ${zlib_need} == true
    then
        echo "ZLIB: force install"
    else
        echo "ZLIB: force noinstall"
    fi
fi

# Провекра Nginx
if test "${nginx_need}" == ""
then
    if ! test -e "/usr/sbin/nginx"
    then
        echo "Nginx: not found (will be installed)"
        nginx_need=true
    else
        echo "Nginx: found"
        nginx_need=false
    fi
else
    if test ${nginx_need} == true
    then
        echo "Nginx: force install"
    else
        echo "Nginx: force noinstall"
    fi
fi
# ----------------------------------------------

# ----------------------------------------------
# ----------------------------------------------
# ----------------------------------------------












# Если мод command_list, то просто печатаем команды в файл,
# иначе - исполняем
function _exec {
    if [ ${command_list} == true ];
    then
        printf "%s\n" "$1" >> command_list.txt
    else
        eval "$1" || exit 1
    fi
}

# Если мод command_list, то ничего не выводим
function _echo {
    if [ ${command_list} == false ];
    then
        echo "$1"
    fi
}

# Загрузка и распаковка пакетов
# Пакеты загружаются все возможные (не имеет значения нужны они или нет)
if ! [ -e "nginx_conf.patch" ]
then
    _exec "wget --no-check-certificate -O nginx_conf.patch https://raw.githubusercontent.com/fullincome/scripts/master/nginx-gost/nginx_conf.patch"
fi

if ! [ -e "${pcre_ver}.tar.gz" ]
then
    _exec "wget --no-check-certificate -O ${pcre_ver}.tar.gz ${url}/src/${pcre_ver}.tar.gz"
fi

if ! [ -e "${zlib_ver}.tar.gz" ]
then
    _exec "wget --no-check-certificate -O ${zlib_ver}.tar.gz ${url}/src/${zlib_ver}.tar.gz"
fi

for openssl_pkg in "${openssl_packages[@]}"; 
do 
    if ! [ -e "$openssl_pkg" ]
    then
        _exec "wget --no-check-certificate -O $openssl_pkg ${url}/bin/${revision_openssl}/$openssl_pkg"
    fi
done

if ! [ -d "$pcre_ver" ]
then
    _exec "tar -xzvf ${pcre_ver}.tar.gz"
fi

if ! [ -d "$zlib_ver" ]
then
    _exec "tar -xzvf ${zlib_ver}.tar.gz"
fi

if (! test -d "$csp" && test "$csp_need" == "true")
then
    if ! [ -d csp ]
    then
        _exec "mkdir csp"
    fi
    _exec "tar -xzvf $csp -C csp --strip-components 1"
    csp="csp"
fi

# ----------------------------------

# Инсталяция пакетов
# Инсталируются только необходимые пакеты, которые не нашлись в системе
if [ ${gcc_need} == true ];
then
    _echo "Install gcc"
    _exec "$apt install gcc"
fi

if [ ${git_need} == true ];
then
    _echo "Install git"
    _exec "$apt install git"
fi

if [ ${csp_need} == true ];
then
    _echo "Install CSP"
    cmd=$install" lsb-cprocsp-kc2*"${pkgmsys}
    _exec "cd ${csp} && ./install.sh && eval ${cmd} && cd ${WORK_PATH}"
fi

if [ ${pcre_need} == true ];
then
    _echo "Install PCRE"
    _exec "cd ${pcre_ver} && ./configure && make && make install && cd ${WORK_PATH}"
fi

if [ ${zlib_need} == true ];
then
    _echo "Install ZLIB" 
    _exec "cd ${zlib_ver} && ./configure && make && make install && cd ${WORK_PATH}"
fi

if [ ${openssl_need} == true ];
then
    _echo "Install Openssl-1.1.0"
    for openssl_pkg in "${openssl_packages[@]}"; do
        cmd=$install" "$openssl_pkg
        _exec "eval ${cmd}"
    done
fi

# ----------------------------------

# Установка nginx
if ! [ -d "nginx" ]
then
    _echo "Clone nginx repository"
    _exec "git clone https://github.com/nginx/nginx.git"
    _exec "cd nginx"
    _echo "Switch branch"
    _exec "git checkout branches/${nginx_branch}"
fi
cd "${WORK_PATH}"

if [ ${nginx_need} == true ];
then
    _echo "Apply patch"
    _exec "cd ${WORK_PATH} && cp nginx_conf.patch ./nginx/nginx_conf.patch"
    _exec "cd nginx && git apply nginx_conf.patch"
    
    cmd="./auto/configure${nginx_paths}${nginx_parametrs}${cc_ld_opt}"
    _echo "Nginx: configure and install"
    _exec "${cmd} && make && make install"
    _echo "Nginx: installed"
else
    if test -e "/usr/sbin/nginx"
    then
        _echo ""
        _echo "Nginx already installed."
    fi
fi

if ! [ -d /var/cache/nginx ]
then
    _exec "mkdir /var/cache/nginx"
fi
cd "${WORK_PATH}"
# ----------------------------------
