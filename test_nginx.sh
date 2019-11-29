#!/bin/bash +x

echo GET / HTTP/1.1 | \
    /opt/cprocsp/cp-openssl-1.1.0/bin/amd64/openssl s_client -engine gostengy -connect localhost:443 -cipher RSA \
    1>output_rsa.txt \
    2>error_rsa.txt

echo GET / HTTP/1.1 | \
    /opt/cprocsp/cp-openssl-1.1.0/bin/amd64/openssl s_client -engine gostengy -connect localhost:443 \
    1>output_gost.txt \
    2>error_gost.txt

cat "output_rsa.txt" | grep "Cipher.*:.*AES" 
ret_rsa=$?

cat "output_gost.txt" | grep "Cipher.*:.*GOST"
ret_gost=$?

if [ $ret_rsa -ne 0 ] || [ $ret_gost -ne 0 ]; then
    cat "output_rsa.txt" "error_rsa.txt" "output_gost.txt" "error_gost.txt"
    echo "FAIL"
    exit 1
fi

echo "OK"
