#!/bin/bash

# "$Id: test.sh,v 1.24 2020/07/28 14:18:10 oren Exp $"
#
# Run script for Memwalk
#
# Copyright (c) ScaleMP, Inc.  2018
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
# (1) The above copyright notice and this permission notice shall be included in
#     all copies or substantial portions of the Software.
# (2) THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

#
# Usage: ./test [percentage]
#
# If percentage omitted (recommended), default will be set by Memwalk binary
#

results=results.out.`date +%y%m%d-%H%M%S`

if [[ $EUID -ne 0 ]]; then
	echo "This program must be run as root. Exiting."
	exit 1
fi

# Find tools
instversion=""
instctl=""

if [ ! -z "${TOOLS_PREFIX}" ]; then
	instversion=${TOOLS_PREFIX}version
	instctl=${TOOLS_PREFIX}ctl
else
	for fname in `echo -n /usr/local/bin/????version`; do
		grep -aq "vsmpversion" $fname 2>&1
		if [ $? == 0 ]; then

			# skip it if it doesn't run
			$fname > /dev/null 2>&1
			if [ $? != 0 ]; then
				continue
			fi

			# found it
			instversion=$fname
		instctl=`basename $fname | awk '{print substr($0,1,4)"ctl"}'`
			break
	    fi
	done
fi

if [ -z "$instversion" ]; then
	echo "This program is not designed to run on bare-metal systems. Exiting."
	exit 1
fi
$instversion --long > $results

echo -n "THP status: " >> $results
grep ^ /sys/kernel/mm/transparent_hugepage/enabled &>> $results

primary_memory=`$instversion --long | grep Private -A1 | tail -1 | sed 's/^.*x *\([0-9MGB]*\).*$/\1/' | awk '{if ($NF ~ /GB/) $NF *= 1024; $NF *= 1024*1024; print $NF}'`

# Create CPU list - for program affinity
cpus=0
cpulist=""
for node in /sys/devices/system/node/node[0-9]* ; do
	dist=`awk '{print $1}' <$node/distance`
	if [ $dist -lt 200 ] ; then
    		for cpu in `ls -d1 $node/cpu[0-9]* 2>/dev/null`; do
			newcpu=`basename $cpu | sed 's/cpu//'`
			isonline=1
                        if [ -e "$cpu/online" ]; then
                                isonline=`cat $cpu/online`
                        fi

                	if [ "$isonline" -eq 1 ]; then
				newcpu="$newcpu "
                                cpulist="$cpulist$newcpu"
                                cpus=$((cpus+1))
			fi
		done
	fi
done
cpulist="`echo $cpulist | sed 's/ /\n/g' | sort -n`"
cpulist="`echo $cpulist | sed 's/ /,/g'`"
echo "cpulist=$cpulist"
# Find current CMR level, to be used for setting program concurrency
cmr=`$instctl --cmr | head -1 | awk '{print $3}'`
if [ "_$cmr" == "_yes" ]; then
	cmr=`$instctl --cmr | tail -1 | awk '{print $4}'`
else
	cmr=1
fi

# Ensure Linux will not be too upset about using all memory
ulimit -s unlimited
ulimit -v unlimited
echo 0 > /proc/sys/vm/overcommit_memory

# Build Memwalk - if its not already built
if [ ! -e ./memwalk ]; then
	echo Building memwalk executable ...
	gcc -g -o memwalk -O2 -fopenmp memwalk.c
	echo Building memwalk executable ... done.
fi

percentage=0

if [ ! -z "$1" -a "$1" != "processes" ]; then
	if [ $1 -eq $1 ]; then
		percentage=$1
	fi
fi

echo $@ | grep -q processes
if [ "$?" -eq 0 ]; then

	nproc=$((cpus*cmr))

	cpus=(`cat /proc/cpuinfo  |egrep "processor|physical id|core id" |paste - - - |awk '{if (!m[$7][$11]) {c[$7][$11]=$3+1} else {c[$7][$11 + 100]=$3+1}; m[$7][$11]=1} END {for (i=0; i< 200;i++) for (j=0;j<8;j++) if ( c[j][i]) print c[j][i]-1}'`);



	trap "echo; echo 'Detected kill signal.'; echo 'Killing all child processes and existing...'; trap - SIGTERM && kill -- -$$" SIGINT SIGTERM
	export OMP_NUM_THREADS=1


	echo Running Memwalk on $cpus CPUs, using $nproc processes

	for i in `seq 0 $((nproc-1))`; do
		(./memwalk "${STDOUT_FILE}" $percentage $primary_memory $nproc $i |tee -a $results) &
	done

	$(ps -eo pid,cmd |grep memwalk |grep -v grep |awk -v var="${cpus[*]}"  '{split(var,cpus," "); printf(" taskset -pc %d %s\n", cpus[n+1], $1); n++; if (n==length(cpus)) n=0 }') ;

	wait

	echo All done - printing Avg

	grep "iter " $results |awk '{print $3}' |sort| uniq  |while read i; do for w in with without; do grep ": iter $i $w " $results |awk '{s+=$18} END {if (s) printf("Avg iter %s %s the primary : %d MB/s\n", $3, $4,s)}'; done; done

else

	export OMP_NUM_THREADS=$((cpus*cmr))
	export GOMP_CPU_AFFINITY=$cpulist

	echo
	echo Running Memwalk on $cpus CPUs, using $OMP_NUM_THREADS threads
	./memwalk "${STDOUT_FILE}" $percentage $primary_memory | tee -a $results

fi
