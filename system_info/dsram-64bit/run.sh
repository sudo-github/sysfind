#! /bin/bash

ulimit -s unlimited

ncpus=`grep -c processor /proc/cpuinfo`
taskset -pc 0-$((ncpus-1)) $$
. ../topo.sh

nboards=$VSMP_BOARD_COUNT
cpusperboard=$VSMP_CPUS_PER_BOARD
ncpus=$((nboards*cpusperboard))

if [ $nboards -le 1 ] ; then
  echo "Only one board, DSRAM test skipped."
  exit
fi

HOST=`hostname | sed 's/[-_].*//'`
VSMP=`vsmpversion --version | head -1 | awk '{print $2}'`
KERNEL=`uname -r`

LIST="$cpusperboard"
half=$((cpusperboard/2))
quarter=$((cpusperboard/4))
minimum=$cpusperboard
if [ $((quarter*4)) -eq $cpusperboard ] ; then
  LIST="$quarter $half $((quarter+half)) $LIST"
  minimum=$quarter
elif [ $half -gt 0 ] ; then
  LIST="$half $LIST"
  minimum=$half
fi

[ $minimum -gt 4 ] && LIST="4 $LIST"
[ $minimum -gt 2 ] && LIST="2 $LIST"
[ $minimum -gt 1 ] && LIST="1 $LIST"
MEGA=1
if [ "$1" != "MEGA" ]; then
	grep GenuineIntel /proc/cpuinfo >/dev/null
	[ $? -ne 0 ] && MEGA=0
	[ $cpusperboard -gt 32 ] && MEGA=0
fi

./compile.sh

tag=`date +%s`
log=log-$tag.txt
out=output-$tag.txt
echo > $log
echo SLP:DSRAM Test >> $log
first=1


for m in `seq 0 $MEGA`; do
	npage_sets=1

	if [ "$MEGA" -eq 0 ]; then
		echo -en "\r[CPUs/Board:" >/dev/tty
	else
		if [ $m -eq 1 ]; then
			npage_sets=$nboards
			echo -en "\r[CPUs/Board/FullDuplex:" >/dev/tty
		else
			echo -en "\r[CPUs/Board/HalfDuplex:" >/dev/tty
		fi
	fi

	for i in $LIST; do
		echo -n " $i" >/dev/tty
		echo "DSRAM stress test : $i thread chains with $npage_sets page-set (starting from last CPU)"
		./Bench_RR -o $out -s $npage_sets -l $i -b $VSMP_BOARDCOUNT -m $VSMP_CPUS_PER_BOARD

		if [ $i -eq 1 ]; then
			grep sls $out | awk '{print "SLP:"$0}' >> $log 2>&1
			grep cls $out | awk '{print "SLP:"$0}' >>$out.1 2>&1
		else
			grep sls $out | tail -1 | awk '{print "SLP:"$0}' >> $log 2>&1
		fi

	done
	echo "]" >/dev/tty
done


cat $out.1 >>$log
cat $log
rm $log $out $out.1
