#!/bin/bash

# $Header: /raid/cvsroot/ScMP64/tools/installer/system_info/function.sh,v 1.29 2020/03/03 09:59:22 michaelm Exp $

MISSING_PACKAGES=""

#return 1 if package is not installed
yum_check()
{
	#dont try to install package if it does not found in repository
	yum info $1 > /dev/null 2>&1
	if [ $? -eq 1 ]; then
		return 0
	fi
	yum list installed $1 > /dev/null 2>&1
	return $?
}

#return 0 on success
yum_install() 
{
	local package="$1"
	local ret_val=1
	yum install ${package} -y
	yum_check ${package}
	ret_val=$?
	echo "Installation of ${package} returned ${ret_val}."
	return ${ret_val}
}

#return 1 if package is not installed
zypper_check()
{
	#dont try to install package if it does not found in repository
	zypper info $1 | grep $1| grep -q "not found"
	if [ $? -eq 0 ]; then
		return 0
	fi
	zypper info $1 | grep ^Status | grep -qv "not installed"
	return $?
}

zypper_install()
{
	local package="$1"
	local ret_val=1
	zypper install -y ${package}
	zypper_check ${package}
	ret_val=$?
	echo "Installation of ${package} returned ${ret_val}."
	return ${ret_val}
}

check_install_type()
{
	which yum > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo yum
		return 0
	fi
	which zypper > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo zypper
		return 0
	fi
	echo ""
	return 1
}

install_missing_tools()
{
	local missing_packages="$@"

	install_func="$(check_install_type)"
	if [ -z "${install_func}" ]; then
		echo "Supported installer not found"
		return 1
	fi
	for i in ${missing_packages}; do
		${install_func}_install ${i}
		echo -n "." > ${STDOUT_FILE}
	done
}

check_needed_tools()
{
	local missing=""
	for util in $@; do
		which ${util} > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			if [ ! -z "${missing}" ]; then
				missing="${missing} "
			fi
			missing="${missing}${util}"
		fi
	done
	echo "${missing}"
}

check_needed_packages()
{
	check_func="$(check_install_type)"
	if [ -z "${check_func}" ]; then
		return
	fi
	for pack in ${NeededPackages[@]}; do
		${check_func}_check ${pack}
		if [ $? -ne 0 ]; then
			MISSING_PACKAGES="${MISSING_PACKAGES}${pack} "
		fi
	done
}

#"show_command_list" 		- print commands list with empty comment part
#"show_command_list comments"	- show all available comments
#"show_command_list all" 	- print all commands
show_command_list()
{
	declare -i num_items=${#Commands[@]}
	declare -i i=0
	local opt="$1"
	while [ ${i} -lt ${num_items} ]; do
		if [ "${opt}" = "comments" ]; then
			if [ ! -z "${Commands[$((${i}+2))]}" ]; then
				echo "${Commands[$((${i}+2))]}"
			fi
		else
			if [ -z "${Commands[$((${i}+2))]}" ] || [ "${opt}" = "all" ]; then
				echo "${Commands[${i}]}"
			fi
		fi
		i=$((${i}+3))
	done
}

show_items()
{
	declare -a Items=($@)
	declare -i num_items=${#Items[@]}
	declare -i i=0
	echo -en "\t"
	declare -i line_len=0
	while [ ${i} -lt ${num_items} ]; do
		cmd="${Items[${i}]}"
		line_len=$((${line_len}+${#cmd}))
		if [ ${line_len} -gt 70 ]; then
			line_len=${#cmd}
			echo -en "\n\t"
		fi
		echo -n "${cmd} "
		i=$((${i}+1))
	done
}

receive_acceptance(){

	echo "The information collected will include the following:"
#Loop in Commands
	echo -e "\n Output of the commands:"
	declare -a ShowList=($(show_command_list | sort -u | xargs))
	show_items ${ShowList[@]}
	echo ""

	set -o noglob
	source commands.sh

	IFS=$'\n' Dirs=($(sort <<<"${Dirs[*]}"))
	IFS=$'\n' Files=($(sort <<<"${Files[*]}"))
	unset IFS

#Show Files list
	echo -e "\n The file list of the directories:"
	show_items ${Dirs[@]}
	echo ""

#Show Files list
	echo -e "\n The contents of the files:"
	show_items ${Files[@]}
	echo ""

	set +o noglob

#Loop in Routines
	echo ""
	declare -i num_items=${#Routines[@]}
	declare -i i=0
	while [ ${i} -lt ${num_items} ]; do
		txt="${Routines[$((${i}+1))]}"
		if [ ! -z "${txt}" ]; then
			echo "${txt}"
		fi
		i=$((${i}+2))
	done

	show_command_list "comments"

	check_needed_packages ${NeededPackages[@]}

	if [ ! -z "${MISSING_PACKAGES}" ] && [ ! -z "$(check_install_type)" ]; then
		echo -e "\n The following utilities will be installed:"
		show_items ${MISSING_PACKAGES}
		echo ""
	fi
	echo ""

	echo "The information is collected to determine status of your system.
The information is captured in a text format, and you will be given
the opportunity to review the collected information."

	if [ ${SILENT} == 0 ]; then
		echo -n "
To EXIT press ENTER.  Type \"accept\" to ALLOW information collection: "

		read reply
		if [ "X$reply" != "Xaccept" ]; then
			echo "
Exiting."
			/bin/rm -rf "${DDN}"
			exit 1
		fi
		echo "
Proceeding with collect information."
		sleep 2
	fi
	echo " "
}

#  Requested 6/22/09 by Sagy:   Add code which runs "which x" for each
#  command 'x' that we run.   Previously, the script uses full pathnames for
#  'x' (so we don't wind up running local versions of commands.)  Now, if
#  the "which x" fails, ask the user where the command is located (that is,
#  prompt the user to type the full pathname where the command lives.)
#command_search_and_prompt(){
#        trial=$*
#        cmdbase=`basename $trial`
#	echo "$trial cmdbase=$cmdbase=" > ${STDOUT_FILE}
#        which $trial > /dev/null 2>&1
#        if [ $? != 0 ]; then
#                echo " " > ${STDOUT_FILE}
#                echo "$trial not found, skipping" > ${STDOUT_FILE}
#                trial="echo CANT RUN: "
#        fi
#        echo $trial
#}


hdd_owner() {

	BDIR=/sys/block
	cd $BDIR
	list=`ls -d sd*`

	echo [Device: numanode: board]
	echo -------------------------
	for hdisk in $list; do
	        cd $BDIR/$hdisk
	        bsize=$(cat size)
	        size=$(((bsize/2) / 1024 **2))
                nodehex=$(cat dev | sed -e 's/.*://')
                node=$((nodehex / 16))
	        if [ ! -z $node ]; then
	                printf "[%s %4d GB: %3d: %3d]\n" $hdisk $size $node $((node/2))
	        fi
	done
	echo -------------------------
	echo
	echo

}

run_and_show_no_dots(){

 	trial=$*
	short_trial=`echo $trial | awk '{print $1}'`
 	cmdbase=`basename $short_trial`
     	which $cmdbase > /dev/null 2>&1
     	if [ $? != 0 ]; then
                echo "$trial not found, skipping"
                echo "`hostname`> "cant find \"$trial\"
     	else

                shift
                args=$*
                echo "`hostname`> " $cmdbase $args
                eval $cmdbase $args 2>&1
                stat=$?
                if [ $stat != 0 ]; then
                echo \*\* ${trial} info:  Above command exited with status $stat \*\*
                echo This is not normally an error which would make this report unusable.
               	echo Please still provide the output file to your service provider.
        	fi
        	echo " "
	fi
}


run_and_show(){
	echo -n . > ${STDOUT_FILE}
	run_and_show_no_dots $*
}



cat_if_present(){
	echo -n . > ${STDOUT_FILE}
	for file in $*; do
		if [ -f $file ]; then
			if [ `file $file | grep -c compressed` -eq 0 ] ; then
				run_and_show cat $file 2>&1
			else
				echo " "
				echo ${cmd_name} info: File $file was not displayed - it is compressed
				echo This is not normally an error which would make this report unusable..
				echo Please still provide the output file to your service provider.
				echo " "
			fi
		else
			echo " "
			echo ${cmd_name} info: File $file was not displayed - it did not exist
			echo This is not normally an error which would make this report unusable..
			echo Please still provide the output file to your service provider.
			echo " "
		fi
	done
	echo " "
}

cat_add_prefix(){
	PREFIX="$1: "
	echo -n . > ${STDOUT_FILE}
	shift
	for file in $*; do
		if [ -f $file ]; then
			echo $PREFIX "*** FILENAME = $file ***"
			while read line; do
			        echo $PREFIX $line
			done < $file
			echo
		else
			echo " "
			echo ${cmd_name} info: File $file was not displayed - it did not exist
			echo This is not normally an error which would make this report unusable..
			echo Please still provide the output file to your service provider.
			echo " "
		fi
	done
	echo " "
}

inspect_output_file(){
	echo " "
	echo System information stored to:
	echo $1
	while ( true ) ; do
		echo " "
		echo -n "Enter 'edit' to inspect this file now, or hit <enter> to continue: "
		read edit_option
		if [ "X$edit_option" == Xedit ]; then
			if [ "X$EDITOR" == X ]; then
				vi "$1"
			else
				$EDITOR "$1"
			fi

		elif [ "X$edit_option" == "X" ]; then
			break;
		fi
	done

}

banner(){
	echo " "
	echo "Please inspect this file and redact any information you do not"
	echo "wish to disclose."
	echo " "
	echo "Please do not interpret any messages you may see in this file."
	echo "Some commands we run may generate informative, warning or "
	echo "even error messages.   We want to see these errors."
	echo " "
	echo "======================== start of collected information ========================"
	echo " "
}

stream_prerequisites()
{
	local missing="$(check_needed_tools tee time)"
	if [ ! -z "${missing}" ]; then
		echo -e "The Stream test will not run. The following packages are required: ${missing}.\n"
		return 1
	fi
	return 0
}

stream_test()
{
	echo " " > ${STDOUT_FILE}
	echo "Running Stream Test Please be patient, it may take some time... " > ${STDOUT_FILE}
	echo Running Stream Test
	cd $testdir/stream; run_and_show "/usr/bin/time ./run.sh"
}

gemm_prerequisites()
{
	local missing="$(check_needed_tools bc time)"
	if [ ! -z "${missing}" ]; then
		echo -e "The GEMM test will not run. The following packages are required: ${missing}.\n"
		return 1
	fi
	return 0
}

gemm_test()
{
	echo " " > ${STDOUT_FILE}
	echo "Running GEMM Test Please be patient, it may take some time..." > ${STDOUT_FILE}
	echo Running GEMM Test
	cd $testdir/mkl; run_and_show "/usr/bin/time ./run.sh"
}

sgemm_prerequisites()
{
	local missing="$(check_needed_tools numactl bc tee time)"
	if [ ! -z "${missing}" ]; then
		echo -e "The SGEMM test will not run. The following packages are required: ${missing}.\n"
		return 1
	fi
	return 0
}

sgemm_test()
{
	echo " " > ${STDOUT_FILE}
	cd $testdir/sgemm
	chmod +x ./run_sgemm.sh
	#send some results also to stdout to indicate progress to user
	sed -i "/numactl/ s/$/ | tee -a \/dev\/tty/" run_sgemm.sh
	echo "Running SGEMM Test Please be patient, it may take some time... " > ${STDOUT_FILE}
	echo "Running SGEMM Test"
	run_and_show "/usr/bin/time ./run_sgemm.sh short"
	grep "Init time" log-gemm*.txt | grep GFlop
}

hpcc_prerequisites()
{
	local missing="$(check_needed_tools bc)"
	if [ ! -z "${missing}" ]; then
		echo -e "The HPCC test will not run. The following packages are required: ${missing}.\n"
		return 1
	fi
	return 0
}

hpcc_test()
{
	echo " " > ${STDOUT_FILE}
	echo "Running HPCC Test Please be patient, it may take some time... " > ${STDOUT_FILE}
	echo Running HPCC Test
	cd $testdir/hpcc ; run_and_show "/usr/bin/time ./run.sh"
}

dsram_test()
{
	echo " " > ${STDOUT_FILE}
	echo "Running DSRAM Test. Please be patient, it may take some time... "> ${STDOUT_FILE}
	echo Running DSRAM Test
	cd $testdir/dsram-64bit; run_and_show "/usr/bin/time ./run.sh $1"
}

memwalk_prerequisites()
{
	if [ "$EUID" -ne 0 ];then
		echo -e "The Memwalk test will not run. The test must be run as root.\n"
		return 1
	fi
	local missing="$(check_needed_tools tee)"
	if [ ! -z "${missing}" ]; then
		echo -e "The Memwalk test will not run. The following packages are required: ${missing}.\n"
		return 1
	fi
	return 0
}

memwalk_test()
{

	echo "Running Memwalk Test. Please be patient, it may take some time..." > ${STDOUT_FILE}
	echo Running Memwalk Test
	testdir=$INFO_BASE
	cd $testdir
	./MemWalk.sh
}
