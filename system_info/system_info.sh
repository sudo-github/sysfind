#!/bin/bash

# $Header: /raid/cvsroot/ScMP64/tools/installer/system_info/system_info.sh,v 1.66.740.1 2021/01/24 20:21:50 michaelm Exp $

# Check and report OS configuration status

source vsmp_constants.exports

declare logging=1
declare persistent_log_collected=0
declare active_log_collected=0
declare version=0
declare SILENT=0
declare isvsmp=0
declare brand_name="${IMAGE_PREFIX}"
declare full_brand_name=""
TESTS_OPTS=""
OUT_FILE_NAME=""
IS_HW_INTERFACE=0
TOOL_VERSION="${INSTALLER_VERSION}"
RUNNING_VERSION="UNKNOWN"
RUNNING_CONFIG="NATIVE"
TIME_OF_TEST=0

trap ctrl_c SIGINT

ctrl_c() {
	cd "${CSI_OUT}"
	rm -rf "${DDN}" "${TFN}"
	echo
	exit
}

if test -t 1; then
	# Stdout is a terminal.
	export STDOUT_FILE="/dev/tty"
else
	# Stdout is not a terminal.
	export STDOUT_FILE=/proc/${PPID}/fd/1
fi

export INFO_BASE=$PWD
env | grep -q SUDO_USER
if [ $? -eq 0 ]; then
	export PATH=$INFO_BASE:$INFO_BASE/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:$PATH
else
	export PATH=$INFO_BASE:$INFO_BASE/bin:$PATH
fi

exit_with_err()
{
rm -rf ${ODN}
exit 1
}

change_tools_name()
{
	mv ${INFO_BASE}/bin/${brand_name}ctl ${INFO_BASE}/bin/${1}ctl
	rm -rf ${INFO_BASE}/bin/${brand_name}version
	rm -rf ${INFO_BASE}/bin/${brand_name}stat
	rm -rf ${INFO_BASE}/bin/${brand_name}prof
	rm -rf ${INFO_BASE}/bin/${brand_name}log
	cp ${INFO_BASE}/bin/${1}ctl ${INFO_BASE}/bin/${1}version
	cp ${INFO_BASE}/bin/${1}ctl ${INFO_BASE}/bin/${1}stat
	cp ${INFO_BASE}/bin/${1}ctl ${INFO_BASE}/bin/${1}prof
	cp ${INFO_BASE}/bin/${1}ctl ${INFO_BASE}/bin/${1}log
}

detect_version_with_dmidecode()
{
	dmidecode -t 11 > t11.txt
	if [ ! -z "$(grep "String 1: Vendor: "		t11.txt)" ] && \
	   [ ! -z "$(grep "String 2: Product Name: "	t11.txt)" ] && \
	   [ ! -z "$(grep "String 3: Version: "		t11.txt)" ] && \
	   [ ! -z "$(grep "String 4: Release Date: "	t11.txt)" ] && \
	   [ ! -z "$(grep "String 5: Serial Number: "	t11.txt)" ] && \
	   [ ! -z "$(grep "String 6: ================================" t11.txt)" ]; then

		RUNNING_VERSION=`grep "String 3: Version: " t11.txt | sed -n 1p | sed -e "s/.*: //" | sed -e "s/(.*//" | sed -e "s/[[:space:]]/_/g"`
		full_brand_name="$(grep "String 1: Vendor: " t11.txt | cut -d ':' -f 3 | xargs) $(grep "String 2: Product Name: " t11.txt | cut -d ':' -f 3 | xargs)"
	else
		RUNNING_VERSION="NATIVE"
		full_brand_name="${BRAND_NAME} ${PRODUCT_NAME}"
	fi
}

check_tools()
{

	if [ ! -z "${HWI_PCI_DEV}" ]; then
		if [ "`cat /sys/bus/pci/devices/${HWI_PCI_DEV}/vendor`" = "0x8686" ]; then
			IS_HW_INTERFACE=1
			if [ "`cat /sys/bus/pci/devices/${HWI_PCI_DEV}/device`" = "0x1010" ]; then
				RUNNING_CONFIG="SYX"
			else
				RUNNING_CONFIG="MEX"
			fi
		fi
	fi

	different_brand=$(${brand_name}version 2>&1 | grep "is not compatible with this" | awk '{print $NF}')
	if [ ! -z "${different_brand}" ]; then
		change_tools_name ${different_brand}
		brand_name=${different_brand}
	fi

	export TOOLS_PREFIX="${brand_name}"

	if [ ${IS_HW_INTERFACE} -eq 1 ]; then
		if [ "$EUID" -eq 0 ];then
			RUNNING_VERSION=`${brand_name}version | sed -n 1p | sed -e "s/.*: //" | sed -e "s/(.*//" | sed -e "s/[[:space:]]//g"`
			full_brand_name="$(${brand_name}version | sed -n 1p | cut -d ':' -f 1)"
		fi
	else
		detect_version_with_dmidecode
	fi

	if [ -z "${full_brand_name}" ]; then
		full_brand_name="run time"
	fi
}

check_tools

source function.sh
source commands.sh

run_ls_on_dirs()
{
	declare -i num_dirs=${#Dirs[@]}
	declare -i i=0

	while [ ${i} -lt ${num_dirs} ]; do
		dn="${Dirs[${i}]}"
		run_and_show ls "-l ${dn}"
		i=$((${i}+1))
	done
}

run_routines()
{
	declare -i num_rtns=${#Routines[@]}
	declare -i i=0
	while [ ${i} -lt ${num_rtns} ]; do
		cmd="${Routines[${i}]}"
		txt="${Routines[$((${i}+1))]}"
		echo "`hostname`>  INFO:" $txt
		${cmd}
		i=$((${i}+2))
		echo " "
	done
}

run_commands()
{
	declare -i num_cmds=${#Commands[@]}
	declare -i i=0

	while [ ${i} -lt ${num_cmds} ]; do
		cmd="${Commands[${i}]}"
		arg="${Commands[$((${i}+1))]}"
		run_and_show "${cmd} ${arg}"
		i=$((${i}+3))
	done
}

cat_files()
{
	for i in `seq 0 $((${#Files[@]}-1))`; do
		cat_if_present ${Files[${i}]}
	done
}
show_ib()
{


 if [ ! -e /sys/class/infiniband ]; then
                return
        fi

        for hca in `ls /sys/class/infiniband`; do
                echo "HCA ${hca} PCI_ADD::`ls -l /sys/class/infiniband/${hca} | awk '{print $11}' | cut -d '/' -f6`   board_id::`cat /sys/class/infiniband/${hca}/board_id`  fw_version::`cat /sys/class/infiniband/${hca}/fw_ver`  node_guid::`cat /sys/class/infiniband/${hca}/node_guid`"

        for port in `ls /sys/class/infiniband/$hca/ports/` ; do

        for file in cap_mask lid lid_mask_count link_layer phys_state rate sm_lid sm_sl state pkeys/0 gids/0 ; do
             echo "HCA $hca:: PORT $port:: FILE $file:: `cat  /sys/class/infiniband/$hca/ports/$port/$file`"

        done
        done
echo " "
        done



}

show_irq_stats()
{
	if [ ! -e /proc/interrupts ]; then
		return
	fi

	cat /proc/interrupts
	sleep 5

	# TODO: instead of printing for second time, we can simply print the
	#       diff from the prvious cat as this is what we want to do anyhow.
	cat /proc/interrupts
}

show_nvmes()
{
	if which nvme >/dev/null 2>&1; then
		run_and_show nvme list
		for nvme in `nvme list | grep ^/ | awk '{print $1}'`; do
			for cmd in "show-regs -H" "id-ctrl -H" "id-ns -H" fw-log smart-log error-log; do
				run_and_show nvme $cmd $nvme
			done
		done
	else
		local nvmes_list=""

		# gather all pathes to nvmes
		for pci_dev in $(find /sys/devices -name nvme -type d); do
			for nvme in $(ls ${pci_dev}); do
				nvmes_list="${nvmes_list}${nvme} ${pci_dev}\n"
			done
		done

		# iterate over all nvmes in a sorted manner
		while IFS= read -r nvme; do
			name=$(echo "${nvme}" | cut -f 1 -d ' ')
			path="$(echo "${nvme}" | cut -f 2- -d ' ')/${name}"

			echo "${name}: "
			cat "${path}"/{model,serial,firmware_rev}
		done < <(echo -e "${nvmes_list}" | sort -n | grep -v "^$") | paste - - - - | sed 's/ \+//g;s/:\t/: /g;s/\t/ | /g'
	fi
}


show_raid_info()
{
RAIDEXIST=(`lspci | grep -o RAID | uniq`);
if [[ $RAIDEXIST == RAID ]] ; then
        if [ -f "/opt/MegaRAID/MegaCli/MegaCli64" ]; then
                    /opt/MegaRAID/MegaCli/MegaCli64 -ShowSummary -aALL
        elif [ -f "/opt/MegaRAID/storcli/storcli64" ]; then
                /opt/MegaRAID/storcli/storcli64  show all
        else
                echo " No RAID tools found"
        fi
else
        echo " No RAID found"
fi
}

show_acpidump()
{
acpidump
if [ $? -ne 0 ]; then
	echo "Trying to dump files /sys/firmware/acpi/tables/ with hexdump"
	local dump_cmd=""
	which xxd > /dev/null
	if [ $? -eq 0 ]; then
		echo "Using xxd -g1"
		dump_cmd="xxd -g1"
	else
		which hexdump > /dev/null
		if [ $? -eq 0 ]; then
			echo "Using hexdump -C"
			dump_cmd="hexdump -C"
		fi
	fi
	local acpi_path=/sys/firmware/acpi/tables
	if [ -d ${acpi_path} ] && [ -n "${dump_cmd}" ]; then
		for acpi_table_name in `ls ${acpi_path}`; do
			if [ -f ${acpi_path}/${acpi_table_name} ]; then
				echo ${acpi_table_name}
				${dump_cmd} ${acpi_path}/${acpi_table_name}
			fi
		done
	fi
fi
}

show_graphic_card_info()
{
	# for Nvidia
	which nvidia-smi > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo "Running: nvidia-smi -L"
		nvidia-smi -L
		echo "Running: nvidia-smi -q"
		nvidia-smi -q
	fi
}

collect_runtime_logs()
{
	if [ ${IS_HW_INTERFACE} -eq 1 ]; then
		if [[ ${logging} == 1 ]]; then
			echo " " > ${STDOUT_FILE}
			echo Getting $full_brand_name logs - this may take a while > ${STDOUT_FILE}

			echo " "
			echo Getting $full_brand_name logs - this may take a while

			${brand_name}log --read=active
			if [ $? -ne 0 ]; then
				echo "Active log read failed. Exiting." > ${STDOUT_FILE}
				exit_with_err
			else
				active_log_collected=1
			fi

			${brand_name}log --read=persistent
			exitstat=$?
			if [ ${exitstat} -ne 0 ]; then
				echo \*\* ${brand_name}log --read=persistent failed with status ${exitstat} \*\*
			else
				persistent_log_collected=1
			fi
			run_and_show ls -ltr
		fi
	fi
}

show_run_time_version()
{
	run_and_show ${brand_name}version --long

	run_and_show ${brand_name}ctl --version

	${brand_name}ctl --features >/dev/null 2>&1
	[ $? = 0 ] && run_and_show ${brand_name}ctl --features
	${brand_name}ctl --status >/dev/null 2>&1
	[ $? = 0 ] && run_and_show ${brand_name}ctl --status
	${brand_name}ctl --binfo >/dev/null 2>&1
	[ $? = 0 ] && run_and_show ${brand_name}ctl --binfo

	run_and_show ${brand_name}ctl --boards

	run_and_show "/bin/rpm -qa | grep vsmp"

	collect_runtime_logs
}

show_net_info()
{
	run_and_show ifconfig -a
	run_and_show route
	run_and_show ip addr
	run_and_show ip route
	for ifc in `cat /proc/net/dev | grep : | awk -F: '{print $1}'`; do
		run_and_show ethtool $ifc
		run_and_show ethtool -d $ifc
		run_and_show ethtool -i $ifc
	done

	for param in /sys/class/net/bond0/bonding/*
	do
		echo -n $param::
		cat $param
	done
}


find_boot_images()
{
	for disk in `cat /proc/partitions | awk '{if ($NF>2) print $(NF-1), $NF}' | egrep '^128\W+[^0-9].*[12]$' | awk '{print $NF}'`; do
		grep -qie "`echo ${BRAND_NAME} ${IMAGE_PREFIX}|cut -c 1-11`" /dev/${disk}
		if [ $? -eq 0 ]; then
			if [[ $disk =~ .*nvme* ]] ; then
				# the device format is nvme0n1p1, and we want to remove "p1"
				disk=`echo $disk | rev | cut -c 3- | rev`
			else
				# the device format is sda2, and we want to remove "2"
				disk=`echo $disk | rev | cut -c 2- | rev`
			fi
			echo "/dev/${disk} `dd if=/dev/${disk} bs=1M count=1 skip=5  2>> /dev/null | grep --binary-files=text -i version | head -1 | tr -dc '[[:print:]]'`"
			#Get logs from VSF labeled drives
			dd if=/dev/${disk} of=${disk}_log.dat bs=1M count=20 skip=12
		fi
	done
	#tar any _log.dat from previous loop files and delete them
	if ls *_log.dat* 1> /dev/null 2>&1; then
		mkdir -p ${ODN}/persistent
		tar -zcvf "${ODN}/persistent/usbnvme_log.tgz" *_log.dat 2>&1
		rm -f *_log.dat 2>&1
	fi
}

#  Option parsing
# $1 output folder
# $2 SILENT flag
# other flags
parse_args()
{
	SILENT=$2
	# set output folder to that installer was ran from
	[ "_$CSI_OUT" = "_" ] && export CSI_OUT="$1"
	shift 2
	TESTS_OPTS="$@"
	echo "$@" | grep -q "S"
	if [ $? -eq 0 ]; then
		OUT_FILE_NAME="system_info"
	else
		OUT_FILE_NAME="performance_test"
	fi

	echo "$@" | grep -q "M"
	if [ $? -eq 0 ]; then
		TIME_OF_TEST=$2
		TESTS_OPTS="M"
		OUT_FILE_NAME="system_info"
	fi
}

system_info() {
	# Check if we have enough disk space to collect system info
	available_space=$(df . --block-size=1M | tail -1 | awk '{print $4}')
	# Space for output and the final archive (sometimes acpi tables are huge)
	needed_space=40
	if [ ${IS_HW_INTERFACE} -eq 1 ]; then
		${brand_name}version | grep -q "NVM devices"
		if [ $? -eq 0 ]; then
			num_nodes=1
		else
			num_nodes=$(${brand_name}ctl --boards)
		fi
		# (size of active and persistent log buffers ) * (num_nodes + 1 reserved)
		needed_space=$((${needed_space}+(${MAX_VSMP_DEV_CAPACITY}-${CRASH_LOG}+${LOG_DATA_BUFFER_SIZE})*(${num_nodes}+1)/1048576))
	fi
	if [ ${needed_space} -gt ${available_space} ]; then
		echo -e "\nError: Not enough free disk space to collect system information." > ${STDOUT_FILE} 
		echo "Available space ${available_space} Mbytes, needed space ${needed_space} Mbytes" > ${STDOUT_FILE}
		exit_with_err
	fi

	banner

	receive_acceptance > ${STDOUT_FILE} 2>&1

	if [ ${SILENT} == 0 ]; then
		echo Received acceptance for data collection from user
		echo at `date`.
		echo " "
	else
		echo "Running in Silent mode..."
	fi

	echo "You may see dots appear to indicate progress as the script continues." > ${STDOUT_FILE}
	echo "There may be a pause of up to a minute between dots - do not be alarmed." > ${STDOUT_FILE}
	echo " " > ${STDOUT_FILE}

	#try to install missing tools
	if [ ! -z "${MISSING_PACKAGES}" ] && [ ! -z "$(check_install_type)" ]; then
		echo "Trying to install missing utilities: ${MISSING_PACKAGES}" > ${STDOUT_FILE}
		echo -n "." > ${STDOUT_FILE}
		install_missing_tools ${MISSING_PACKAGES}
		echo -e "\nInstall finished." > ${STDOUT_FILE}
	fi

	# get some information about the system
	run_routines
	run_ls_on_dirs
	run_commands
	cat_files

	echo " " > ${STDOUT_FILE}
	echo "Now collecting more data..." > ${STDOUT_FILE}
	echo " " > ${STDOUT_FILE}
	echo " "

	cd $ODN

	started=0
	${brand_name}stat --reset | grep -q "not enabled"
	if [ $? -eq 1 ]; then
		run_and_show ${brand_name}stat --reset > /dev/null
		started=1
	else
		run_and_show ${brand_name}stat --start
	fi
	sleep 20
	run_and_show ${brand_name}stat --bbc
	run_and_show ${brand_name}stat --level=2 --outfile=stats

	if [ $started -eq 0 ];then
		run_and_show ${brand_name}stat --stop
	fi

	# Let's collect some information about vsmppp
	cat_add_prefix "VSMPPP" /etc/vsmppp/*
	cat_add_prefix "VSMPPP" /opt/ScaleMP/vsmppp/etc/package.db
	ls /opt/ScaleMP/vsmppp/log/vsmppp_*install*.tar.bz2 > /dev/null 2>&1
	if [ $? -eq 0 ]; then
		cp /opt/ScaleMP/vsmppp/log/vsmppp_*install*.tar.bz2 $ODN
	fi

	cd "${ODN}"

	echo " "
	echo Data collection complete.
	echo " "

	echo " " > ${STDOUT_FILE}
	echo Data collection complete.  > ${STDOUT_FILE}
	echo " " > ${STDOUT_FILE}

	# ============================================================

	if [ ${SILENT} == 0 -a "${STDOUT_FILE}" = "/dev/tty" ]; then
		inspect_output_file "${OFN}" > ${STDOUT_FILE} 2>&1
	fi

	echo " " > ${STDOUT_FILE}
	echo " " > ${STDOUT_FILE}

	echo The information in > ${STDOUT_FILE}
	echo "${OFN}" > ${STDOUT_FILE}
	if [ ${logging} == 1 ]; then
		if [ ${persistent_log_collected} -eq 1 -o ${active_log_collected} -eq 1 ]; then
			echo plus the binary $full_brand_name logs  > ${STDOUT_FILE}
		fi
	fi
	echo will be combined into a tar file.  > ${STDOUT_FILE}

	echo " " > ${STDOUT_FILE}
	if [[ ${logging} == 1 && ${persistent_log_collected} == 1 ]]; then
		mkdir -p persistent
		mv ${brand_name}log*pers*tgz persistent
	fi

	if [[ ${logging} == 1 && ${active_log_collected} == 1 ]]; then
		mkdir -p active
		mv ${brand_name}log*acti*tgz active
	fi

}

system_monitor_test()
{
	echo "Monitoring system activity for the next ${TIME_OF_TEST} seconds."
	echo "System info will be collected at the end of the process."
	
	STATS=$((TIME_OF_TEST/3))
	PROFT=20
	PROFS=$((STATS/PROFT))
	STATT=60
	if [ ${PROFS} -eq 0 ]; then
		PROFS=1
	fi
	mkdir -p monitoring
	cd monitoring
	exec > "monitoring.out" 2>&1

	${brand_name}log --read=active

	${brand_name}stat --outfile ${STATT} 2>/dev/null > started &

	sleep ${STATS}

	for i in `seq 1 ${PROFS}`; do 
		${brand_name}prof --board-events sleep ${PROFT}
	done

	sleep $((${TIME_OF_TEST}-${STATS}-${PROFT}*${PROFS}))

	if [ -s started ]; then
		${brand_name}stat --stop
	fi
	rm -f started
	cd ..

	mv monitoring ${ODN}
	exec >> "${OFN}" 2>&1
	cd "${ODN}"
	system_info
}

run_tests()
{
	echo "Test parameters: $@"

	run_and_show "echo RUNNING_VERSION=${RUNNING_VERSION}"
	if [ ${IS_HW_INTERFACE} -eq 1 ]; then
		run_and_show "${brand_name}version --long"
	fi

	echo "$@" | grep -q "S"
	if [ $? -eq 0 ]; then
		system_info
	fi

	testdir=$INFO_BASE
	cd $testdir

	for opt in `echo $@ | grep -o . | sort -u`; do
		case ${opt} in
			m)
				if [ "${RUNNING_CONFIG}" = "MEX" ]; then
					memwalk_test
				fi
			;;
			t)
				stream_test
			;;
			g)
				gemm_test
			;;
			h)
				if [ "${RUNNING_CONFIG}" = "SYX" ]; then
					hpcc_test
				fi
			;;
			d)
				if [ "${RUNNING_CONFIG}" = "SYX" ]; then
					dsram_test
				fi
			;;
			D)
				if [ "${RUNNING_CONFIG}" = "SYX" ]; then
					dsram_test MEGA
				fi
			;;
			s)
				if [ "${RUNNING_CONFIG}" = "MEX" -o "$@" = "s" ]; then
					sgemm_test
				fi
			;;
			S)
				echo "System info already run."
			;;
			M)
				system_monitor_test
			;;
			*)
				echo "Unknown test option \"${opt}\"." > ${STDOUT_FILE}
				echo "Unknown test option \"${opt}\"."
			;;
		esac
	done
}

run_tests_check_prerequisites()
{
	local ret_val=0
	local missing="$(check_needed_tools taskset)"
	if [ ! -z "${missing}" ]; then
		echo -e "The tests will not run. The following packages are required: ${missing}.\n"
		return 1
	fi
	for opt in `echo $@ | grep -o . | sort -u`; do
		case ${opt} in
		m)
			memwalk_prerequisites
		;;
		s)
			sgemm_prerequisites
		;;
		g)
			gemm_prerequisites
		;;
		h)
			hpcc_prerequisites
		;;
		t)
			stream_prerequisites
		;;
		*)
		;;
		esac
		ret_val=$((${ret_val}+$?))
	done

	return ${ret_val}
}


main()
{

	run_tests_check_prerequisites ${TESTS_OPTS}
	#if one of test prerequisites fails return
	if [ $? -ne 0 ]; then
		return
	fi

	export MALLOC_CHECK_=0

	HOSTNAME=`hostname | sed -e "s/[^[:alnum:]]/_/g"`
	TIMESTAMP=`date +%Y-%m-%d-%H%M%S-%Z | sed -e "s/[^-[:alnum:]]/_/g"`

	#  Determine the directory where we'll be putting stuff.

	TAG=${OUT_FILE_NAME}-${HOSTNAME}-${RUNNING_VERSION}-${TIMESTAMP}
	#  Tar File Name
	TFN=${TAG}.tgz
	#  Output Directory Name
	ODN="${CSI_OUT}/${TAG}"
	#  Delete Directory Name
	DDN="${CSI_OUT}/${TAG}"
	mkdir -p "${ODN}" > /dev/null 2>&1
	if [ ! -d "${ODN}" ]; then
		#  Old Output Directory Name
		OODN="${ODN}"
		TFN=/tmp/${TAG}.tgz
		ODN=/tmp/${TAG}
		mkdir -p "${ODN}"
		if [ ! -d "${ODN}" ] ; then
			echo " "
			echo Could not create $ODN or $OODN - some of the possible causes:
			echo "     1)  Disk is full"
			echo "     2)  Filesystem is mounted read-only"
			echo "     3)  User 'root' is trying to write to an NFS-mounted filesystem for which it lacks permission"
			echo " "
			echo "Please determine the cause, correct and re-run."
			exit 1
		fi
	fi

	#   This makes the logs go to ${ODN}.  And makes "tar" happy if we're running it
	#   to consolidate the logs and text output.
	#   Output Directory Name
	cd "${ODN}"

	#  Output File Name
	OFN="${ODN}/${OUT_FILE_NAME}.out"
	touch "${OFN}"
	if [ ! -f "${OFN}" ] ; then
		echo " "
		echo Could not create ${OFN} - some of the possible causes:
		echo "     1)  Disk is full"
		echo "     2)  Filesystem is mounted read-only"
		echo "     3)  User 'root' is trying to write to an NFS-mounted filesystem for which it lacks permission"
		echo " "
		echo "Please determine the cause, correct and re-run."
		exit 1
	fi

	echo Output is going to $TFN

	# Copy OS install logs.
	#cp -p /root/install.log* ${ODN}/
	#First output
	exec > "${OFN}" 2>&1
	echo $0 version: "${INSTALLER_VERSION}"

	#here the sysinfo runs
	run_tests ${TESTS_OPTS}

	cd "${ODN}/.."

	echo /bin/tar cvfz ${TFN} "${ODN}"
	/bin/tar cvfz ${TFN} ${TAG}
	echo tar tvfz ${TFN}
	tar tvfz ${TFN}
	if [ $? != 0 ]; then
		echo " " > ${STDOUT_FILE}
		echo \*\* tar took an error exit.  The tar output file, ${TFN}, is probably \*\* > ${STDOUT_FILE}
		echo \*\* missing or useless. \*\*    > ${STDOUT_FILE}
		echo " " > ${STDOUT_FILE}
		echo " " > ${STDOUT_FILE}

		if [ -f "${OFN}" ]; then
			echo Please send the file ${OFN} to your support provider. > ${STDOUT_FILE}
		else
			echo Something strange happened - ${ODN} is no longer present. > ${STDOUT_FILE}
			echo \*\* Please contact your service provider. \*\* > ${STDOUT_FILE}
		fi

		echo " " > ${STDOUT_FILE}
		exit 1
	fi

	/bin/rm -rf "${DDN}"

	if [ ${SILENT} -ge 2 ] ; then
		echo " " > ${STDOUT_FILE}
		echo Please send the file ${TFN} to your support provider > ${STDOUT_FILE}
	fi

	if [[ ${logging} == 1 && ${persistent_log_collected} == 1 && ${active_log_collected} == 1 ]]; then
		exit 0
	else
		if [[ ${logging} == 0 ]]; then
			exit 0
		fi
		exit 1
	fi
}

starting_dir="$1"
shift
parse_args "${starting_dir}" $@
shift 2
main $@
exit 0
