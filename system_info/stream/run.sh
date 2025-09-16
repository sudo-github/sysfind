#!/bin/bash

export ncpus=`grep -c processor /proc/cpuinfo`
taskset -pc 0-$((ncpus-1)) $$

. ../topo.sh

export KMP_AFFINITY=explicit,proclist=[$VSMP_OPT_CPU_LIST],granularity=fine
echo "CPU Affinity used: $VSMP_OPT_CPU_LIST"

nboards=$VSMP_BOARD_COUNT
cpusperboard=$VSMP_CPUS_PER_BOARD
ncpus=$((nboards*cpusperboard))

cmd=./stream_omp.intel

log=log-`date +%s`.txt
out=results.txt
echo > $out
echo SLP:Stream Triad >> $out

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
	echo " ======================= $OMP_NUM_THREADS ===================" 
	[ $np -eq 1 ] && prefix="taskset -c $((cpusperboard-1))"
	[ $np -ne 1 ] && prefix=""
	$prefix $cmd $((OMP_NUM_THREADS*10000000)) 2>&1 | grep -v "Ignoring invalid OS proc ID" | tee $log
	echo
  
	ostr=`grep Triad $log| awk '{print $1 "   " $2}'`
	printf "SLP:Stream [CPUs=%3d]: %s\n" "$np" "$ostr" >> $out
done
echo "]" >/dev/tty

export OMP_NUM_THREADS=$cpusperboard
echo >> $out
echo -n "[Board level:" >/dev/tty
for BD in $(seq 0 $(($nboards-1))); do
	echo -n " $BD" >/dev/tty
        prefix="taskset -c `echo ${cpus_board[$BD]} | sed 's/ /,/g'`"
	echo " "
	echo " ================ $OMP_NUM_THREADS on board $BD ============"  
	$prefix $cmd $((OMP_NUM_THREADS*10000000)) 2>&1 | grep -v "Ignoring invalid OS proc ID" | tee $log

	ostr=`grep Triad $log| awk '{print $1 "   " $2}'`
	printf "SLP:Stream [BD#=%3d]: %s\n" "$BD" "$ostr" >> $out
	echo
done
echo "]" >/dev/tty

echo SLP:End of Stream Triad >> $out
echo >> $out
echo >> $out
cat $out
rm $log $out

