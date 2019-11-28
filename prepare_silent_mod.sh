cpro_path="/opt/cprocsp"
dsrf_path="/var/opt/cprocsp/dsrf"
cpconfig="${cpro_path}/sbin/amd64/cpconfig"

${cpconfig} -hardware rndm -add cpsd -name 'cpsd rng' -level 2 &&
${cpconfig} -hardware rndm -configure cpsd -add string /db1/kis_1 "${dsrf_path}/db1/kis_1" &&
${cpconfig} -hardware rndm -configure cpsd -add string /db2/kis_1 "${dsrf_path}/db2/kis_1" &&
cp ./mydsrf "${dsrf_path}/db1/kis_1" &&
cp ./mydsrf "${dsrf_path}/db2/kis_1" &&
/etc/init.d/cprocsp restart
 