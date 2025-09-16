#!/bin/bash

ncpus=`grep -c processor /proc/cpuinfo`
taskset -pc 0-$((ncpus-1)) $$
. ../topo.sh

nboards=$VSMP_BOARD_COUNT
cpusperboard=$VSMP_CPUS_PER_BOARD
ncpus=$((nboards*cpusperboard))
total_mem=`free -g|grep Mem|awk '{print $2}'`
memperboard=$((($total_mem / $nboards) * 7 / 10))

BASE=`pwd`
MPI_DIR=/opt/ScaleMP/mpich
if [ -d $MPI_DIR ] ; then
	MPI_VER=$(cd $MPI_DIR; ls -d 3* | grep -v [a-Z] | sort | tail -1)
else
	MPI_DIR=/opt/ScaleMP/mpich2
	MPI_VER=$(cd $MPI_DIR; ls -d 1* | grep -v [a-Z] | sort | tail -1)
fi
if [ "_$MPI_VER" = "_" ]; then
	echo MPICH is missing.
	exit 1
fi
export MPI_ROOT=$MPI_DIR/$MPI_VER
echo USING MPICH at $MPI_ROOT
export PATH=$MPI_ROOT/bin:$PATH
export VSMP_PLACEMENT=PACKED
export VSMP_VERBOSE=YES
export MALLOC_TOP_PAD_=4294967296
export LD_PRELOAD=/opt/ScaleMP/libvsmpclib/lib64/libvsmpclib.so
ulimit -s unlimited

t="$cpusperboard"
for more in 2 4 8 ; do
	if [ $((cpusperboard * more)) -le $ncpus ]; then
		list="$list $((cpusperboard * more))"
	fi
done

input=hpccinf.txt

out=log.txt
echo > $out
echo "SLP:HPCC [PingPong]" >> $out
if [ ! -f $MPI_ROOT/bin/mpirun ]; then
	echo "SLP: $MPI_ROOT/bin/mpirun is not found" >> $out
	echo "SLP:End of HPCC" >> $out
	cat $out
	exit 1 
fi

rm -f hpccoutf.txt 

echo -en "\r[System wide:" >/dev/tty
for NPROC in $list; do
	echo -n " $NPROC" >/dev/tty
	row=`echo 'sqrt('$NPROC')' | bc`
	col=$(($NPROC/$row))
	while [ $(($row * $col)) -ne $NPROC ]; do
		row=$(($row-1))
		col=$(($NPROC/$row))
	done

	cp -p _hpccinf.txt $input

	sed -e '11s/^1/'$row'/' -i $input
	sed -e '12s/^1/'$col'/' -i $input

	mpirun -np $NPROC ./hpcc 
	for val in MinPingPongLatency_usec AvgPingPongLatency_usec MaxPingPongBandwidth_GBytes AvgPingPongBandwidth_GBytes NaturallyOrderedRingLatency_usec RandomlyOrderedRingLatency_usec NaturallyOrderedRingBandwidth_GBytes RandomlyOrderedRingBandwidth_GBytes ; do
		ostr=`grep $val hpccoutf.txt`
		printf "SLP:HPCC [CPUs=%3d]: %s\n" "$NPROC" "$ostr" >> $out
	done

	rm hpccoutf.txt 
done
echo "]" >/dev/tty

echo "SLP:End of HPCC" >> $out
cat $out
rm $out
