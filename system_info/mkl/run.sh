#!/bin/bash

ncpus=`grep -c processor /proc/cpuinfo`
taskset -pc 0-$((ncpus-1)) $$
. ../topo.sh

ulimit -s unlimited
export MKL_DYNAMIC=FALSE
export OMP_SCHEDULE=STATIC

tag=`date +%s`
nboards=$VSMP_BOARD_COUNT
cpusperboard=$VSMP_CPUS_PER_BOARD
ncpus=$((nboards*cpusperboard))

basesize=3999

if [ $INTELCPU -eq 1 -o $VSMP_BOARD_COUNT -gt 1 ] ; then
  export KMP_AFFINITY=explicit,proclist=[$VSMP_OPT_CPU_LIST],granularity=fine
  CMD=../sgemm/mkl-seg
  MATH=MKL
else
  export GOMP_CPU_AFFINITY=$VSMP_OPT_CPU_LIST
  CMD=../sgemm/amd-seg
  MATH=BLIS
fi

echo "CPU Affinity used: $VSMP_OPT_CPU_LIST"

cpuspeed=`cat /proc/cpuinfo |grep MHz|head -1|awk '{print $4}'`
MFLOPS=${cpuspeed/.*} 
MFLOPS=$(($MFLOPS * 8))

log=log.txt
out=results.txt
echo > $out
echo SLP:$MATH "[1 CPU = $MFLOPS MFlops/sec]" >> $out

num=$cpusperboard
while [ $num -gt 2 ]; do
	list=$num" "$list
	num=$(($num/2))
done
list="1 2 "$list
num=$(($cpusperboard*2))
while [ $num -le $ncpus ]; do
	list=$list" $num"
	old=$num
	num=$(($num * 2))
	if [[ $old -lt $ncpus && $num -gt $ncpus ]]; then
		num=$ncpus
	fi
done

echo -en "\r[System wide:" >/dev/tty
for np in $list; do
	echo -n " $np" >/dev/tty
	export OMP_NUM_THREADS=$np
	export MKL_NUM_THREADS=$np
	if [ $np -le $((cpusperboard/threads)) ]; then
		unset MKL_NUM_STRIPES
	else
		export MKL_NUM_STRIPES=$((nodecpus[0]/threads))
		[ $MKL_NUM_STRIPES -lt $((np/(cpusperboard/threads))) ] && export MKL_NUM_STRIPES=${nodecpus[0]}
		[ $MKL_NUM_STRIPES -lt $((np/(cpusperboard/threads))) ] && export MKL_NUM_STRIPES=$((cpusperboard/threads))
	fi
	size=`echo "scale=4; x=sqrt($basesize*$basesize*$np/sqrt(sqrt($np))); scale=0; x" | bc`
	[ $np -eq 1 ] && prefix="taskset -c $((cpusperboard-1))"
	[ $np -ne 1 ] && prefix=""
	$prefix $CMD $size $size $size $size $size $size 2 2>&1 | grep -v "Ignoring invalid OS proc ID" | tee $log
	echo ********************************
	echo

	ostr=`grep "Part    1" $log | tail -1 | awk '{print $8,$9}'`
	printf "SLP:$MATH [CPUs=%3d]: %s\n" "$np" "$ostr" >> $out
done
echo "]" >/dev/tty

echo >> $out
unset MKL_NUM_STRIPES
export OMP_NUM_THREADS=$cpusperboard
export MKL_NUM_THREADS=$cpusperboard

size=`echo "scale=4; x=sqrt($basesize*$basesize*$cpusperboard/sqrt(sqrt($cpusperboard))); scale=0; x" | bc`
echo "Running $cpusperboard way $MATH on each boards!"
echo
echo -n "[Board level:" >/dev/tty
for BD in $(seq 0 $(($nboards-1))); do
	echo -n " $BD" >/dev/tty
	if [ $INTELCPU -eq 1 -o $VSMP_BOARD_COUNT -gt 1 ] ; then
		export KMP_AFFINITY=explicit,granularity=fine,proclist=[`echo ${cpus_board[$BD]} | sed 's/ /,/g'`]
	else
		export GOMP_CPU_AFFINITY="`echo ${cpus_board[$BD]} | sed 's/ /,/g'`"
	fi
	echo "Running $cpusperboard way on BD #$BD ..."
	$CMD $size $size $size $size $size $size 2 2>&1 | grep -v "Ignoring invalid OS proc ID" | tee $log
	echo ********************************
	echo
	ostr=`grep "Part    1" $log | tail -1 | awk '{print $8,$9}'`
	printf "SLP:$MATH [BD#=%3d]: %s\n" "$BD" "$ostr" >> $out
done
echo "]" >/dev/tty

echo SLP:End of $MATH >> $out
echo >> $out
echo >> $out
cat $out
rm $log $out

