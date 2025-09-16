#! /bin/bash

export LANG=C
INTELCPU=`grep "model name" /proc/cpuinfo | head -n 1 | grep -ci intel`

pushd $PWD &>/dev/null
cd /sys/devices/system/node
topolist="`ls -d node[0-9]* | sed 's/node//g' | sort -n`"
topolist=( $topolist )

for (( i = 0; i < ${#topolist[*]}; i++ )) ; do
  cd /sys/devices/system/node/node${topolist[$i]}
  nodecpus[$i]=`ls -d cpu[0-9]* 2>/dev/null | wc -l`
  nodemem[$i]=$(( `grep MemTotal: meminfo | awk '{print $4}'` / 1024 ))
  cpus_node[$i]="`ls -d cpu[0-9]* 2>/dev/null | sed 's/cpu//g' | sort -n`"
done

nboard=0
for (( i = 0; i < ${#topolist[*]}; i++ )) ; do
  cd /sys/devices/system/node/node${topolist[$i]}
  if [[ "_${boards[$i]}" == "_" ]] ; then
    boardcpus[$nboard]=0
    dist=( `cat distance` )
    for (( j = 0; j < ${#dist[*]}; j++ )) ; do
      if [ ${dist[$j]} -ne 254 ] ; then
        boards[$j]=$nboard
        boardcpus[$nboard]=$((boardcpus[$nboard]+nodecpus[$j]))
        boardmem[$nboard]=$((boardmem[$nboard]+nodemem[$j]))
        cpus_board[$nboard]="${cpus_board[$nboard]} ${cpus_node[$j]}"
        nodes_board[$nboard]="${nodes_board[$nboard]} $j"
      fi
    done
    nboard=$((nboard+1))
  fi
done

useboards=0
usememory=0
for (( i = 0; i < $nboard ; i++ )) ; do
  if [ "_${boardcpus[0]}" != "_${boardcpus[i]}" ] ; then break ; fi
  useboards=$((useboards+1))
  usememory=$((usememory+boardmem[$i]))
done
popd &>/dev/null

if [ "_$1" == "_show" ] ; then
  echo "${#topolist[*]} Nodes"
  echo "$nboard Boards"
  echo "${boards[@]:0}"
  echo "CPUs / Node : ${nodecpus[@]:0}"
  echo "CPUs / Board : ${boardcpus[@]:0}"
  echo "Memory to use : $usememory MB"
fi
echo "$useboards Useful Boards out of $nboard (${boardcpus[0]} CPUs each)"
export VSMP_USE_MEMORY=$usememory
export VSMP_BOARD_COUNT=$useboards
export VSMP_CPUS_PER_BOARD=${boardcpus[0]}
# Sanity check against affinity
cpulist=""
topolist="`taskset -pc $$ | awk '{print $6}' | sed 's/,/ /g'`"
for n in $topolist ; do
  if [ `echo $n | grep -c "-"` -eq 1 ] ; then
    fromto="`echo $n | sed 's/-/ /'`"
    fromto="`seq -s ' ' $fromto`"
  else
    fromto=$n
  fi
  cpulist="$cpulist $fromto"
done
cpulist=( $cpulist )
#echo "${#cpulist[*]} ${cpulist[0]} - ${cpulist[${#cpulist[*]}-1]}"
if [ ${cpulist[0]} != 0 ] ; then
  echo "Error: Affinity does not start from CPU 0 - aborted"
  exit 1
fi
if [ ${#cpulist[*]} -lt $((VSMP_BOARD_COUNT*VSMP_CPUS_PER_BOARD)) ] ; then
  export VSMP_BOARD_COUNT=$((${#cpulist[*]}/VSMP_CPUS_PER_BOARD))
  if [ $VSMP_BOARD_COUNT -eq 0 ] ; then
    echo "Error: Affinity does not cover even a single board - aborted"
    exit 2
  fi
  echo "Warning: Affinity does not cover all boards - adjusting to $VSMP_BOARD_COUNT boards"
fi
if [ ${cpulist[$((VSMP_BOARD_COUNT*VSMP_CPUS_PER_BOARD-1))]} -ne $((VSMP_BOARD_COUNT*VSMP_CPUS_PER_BOARD-1)) ] ; then
  echo "Error: Affinity is not consecutive - aborted"
  exit 3
fi

threads=`cat /sys/devices/system/cpu/cpu${cpulist[0]}/cache/index0/shared_cpu_list 2>/dev/null | sed 's/,/ /g' | wc -w`
[ $threads -eq 0 ] && threads=1
thread_cpulist=""
for ((i=0; i < threads; i++)) ; do
  for ((j=0; j < VSMP_BOARD_COUNT; j++)) ; do
    for node in ${nodes_board[$j]} ; do
      ofnode=( ${cpus_node[$node]} )
      perthread=$(( ${#ofnode[@]}/$threads ))
      for ((k=$perthread*$i; k < $perthread*($i+1); k++)) ; do
        thread_cpulist="$thread_cpulist ${ofnode[$k]}"
      done
    done
  done
done
thread_cpulist=( $thread_cpulist )
if [ "_$1" == "_show" ] ; then
  echo "threads=$threads"
  echo "cpus are ${cpulist[@]}"
  echo "by thread, cpus are ${thread_cpulist[@]}"
fi
# LISTS
export VSMP_CPU_LIST=`echo ${cpulist[@]} | sed 's/ /,/g'`
optlist=()
for ((i=0; i < ${#thread_cpulist[@]}; i++)) ; do
  optlist[$i]=${thread_cpulist[${#cpulist[@]}-i-1]}
done
export VSMP_OPT_CPU_LIST=`echo ${optlist[@]} | sed 's/ /,/g'`

