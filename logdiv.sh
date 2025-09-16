#!/bin/bash 

if [[ $# == 0  ]] ; then
     echo $'\n' " USAGE: $0 <sysfind log file> " $'\n' ; exit
else
  LOGF=$1
  if [ ! -f $LOGF ] ; then
     echo $'\n' " No such file : $HOSTF " $'\n' ; exit
  fi
fi

#
array=(`awk '/^:::EL7:::/ {print $(2)}' $LOGF`)
nlog=${#array[@]}
csplit --quiet -n 3 $LOGF '/^:::EL7:::/' '{*}'

BLOGF=`basename ${LOGF}`
#logdir="split_${BLOGF//.*}"
logdir="split_${BLOGF%.*}"
echo "Number of log items = ${nlog}"
echo "log files are saved in ${logdir}"

mkdir -p ${logdir}
mv xx000 ${logdir}/headder.txt
for num in `seq 1 $nlog` ; do
    tool=${array[$(( $num - 1 ))]}
    s3id=`printf "%03d" ${num}`
    cat xx${s3id} >> ${logdir}/${tool##*/}.txt
    /bin/rm -rf xx${s3id}
done

