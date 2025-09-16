#!/bin/bash

# $Header: /raid/cvsroot/ScMP64/tools/installer/system_info/commands.sh,v 1.34 2020/08/17 20:56:15 michaelm Exp $

#Commands to run
# "Commad" "arguments" "Description"
# Command must present. If no arguments or description present, put "" instead!!!
declare -a Commands=(
"uname" "-a" ""
"rpm" "-qa | grep -i kernel" ""
"grep" "-i processor /proc/cpuinfo | wc -l" " The number of CPUs in your system."
"lscpu" "" ""
"lspci" "" ""
"lspci" "-n" ""
"lspci" "-nn" ""
"lspci" "| egrep 'IDE|ATA'" ""
"lspci" "-tv" ""
"lspci" "-vvv" ""
"lspci" "-vvv -xxxx" ""
"lsusb" "" ""
"lsusb" "-tv" ""
"lsusb" "-v" ""
"grep" "-sr ^ /sys/devices/system/clocksource" " The information about the OS clocksource."
"grep" "-sr ^ /sys/kernel/mm | sort" " Various kernel settings and tunables."
"cpupower" "frequency-info" ""
"cpupower" "idle-info" ""
"cpupower" "info" ""
"cpupower" "monitor" ""
"ls" "-ld /sys/firmware/efi" " The /sys/firmware/efi directory properties."
"mount" "" ""
"blkid" "" ""
"lsblk" "-a -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MODEL,MOUNTPOINT" ""
"lsblk" "-a -fs" ""
"fdisk" "-l" ""
"df" "-hT" ""
"free" "" ""
"free" "-g" ""
"ps" "--forest -e" ""
"ps" "-edalfL" ""
"ps" "-eflyL" ""
"ps" "-eaLo f,s,uid,pid,ppid,lwp,c,nlwp,pri,ni,rss,sz,wchan,stime,tty,time,psr,cmd" ""
"chkconfig" "--list" ""
"chkconfig" "--list | /bin/grep :on" ""
"chkconfig" "--list | /bin/grep :off | grep -v :on" ""
"systemctl" "list-unit-files" ""
"env" "| sort" " The list of environment variables."
"dmesg" "" ""
"uptime" "" ""
"pvdisplay" "--verbose" ""
"lvdisplay" "--verbose" ""
"sysctl" "-a" ""
"crontab" "-l" ""
"numactl" "--show" ""
"numactl" "--hardware" ""
"dmidecode" "" ""
"biosdevname" "-d" ""
"efibootmgr" "-v" ""
"mcelog" "--client" ""
"zpool" "status" ""
)

declare -a NeededPackages=(
"bzip2"
"lshw"
"numactl"
"nvme-cli"
)

declare -a Dirs=(
/opt /usr/local/bin /home /boot /lib/modules /etc/cron*
)

#Files to dump
# Put files separated with
declare -a Files=(
/boot/grub/menu.lst /boot/grub/grub.conf /boot/grub2/grub.cfg /boot/grub2/grubenv
/etc/default/grub /etc/auto.* /etc/fstab /etc/rc.local /etc/grub2.conf /etc/mdadm.conf /etc/nsswitch.conf /etc/resolv.conf
/etc/*-release /etc/sysconfig/network-scripts/ifcfg-*
/etc/sysconfig/network/ifcfg-* /etc/sysctl.conf /etc/udev/rules.d/*persistent*
/proc/buddyinfo /proc/cpuinfo /proc/mdstat /proc/modules /proc/slabinfo /proc/swaps /proc/uptime
/proc/vmstat /proc/cmdline /proc/iomem /proc/ioports /proc/loadavg /proc/partitions /proc/kallsyms
/proc/zoneinfo /proc/meminfo /sys/devices/system/node/node*/meminfo /var/log/boot.msg /var/log/messages /var/log/syslog /var/log/mcelog
/boot/config-`uname -r` /sys/devices/system/cpu/vulnerabilities/* /proc/*/status
/opt/ScaleMP/numabind/etc/numabind-config /tmp/numabind.log
)

#List of routines and description
# routine must present, description is not present must be set to ""!!
declare -a Routines=(
show_run_time_version " The version of ${full_brand_name} is running."
find_boot_images " The list of partitions with ${full_brand_name} signature and the log section for each partition."
show_ib " The information about Infiniband devices, if present."
show_nvmes " The list of available NVMe devices."
show_net_info " Partial information about the network configuration on your system."
show_irq_stats " IRQ information from /proc/interrupts."
hdd_owner " NUMA node information for each HDD in the system."
show_raid_info " The RAID information."
show_acpidump " Dump of the ACPI table."
show_graphic_card_info " Graphics card information."
)
