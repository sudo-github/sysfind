#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# import imp
import os
import sys
from argparse import ArgumentParser
import re

def debugprint(debuglst):
    for ent in debuglst:
        print(ent[0:-1])


# ------------------------------------------------------
# 'Usage: {0}   [-d|--debug] [--help]'.format(__file__)
# ------------------------------------------------------
def parser():
    usage = '\n  Usage: {0} [-d|--debug] [-v|--version] [-f|--full] [-q|--quiet] [-n|--dry-run] [-p|--perftest] [-h|--help]'.format(
        __file__)
    argparser = ArgumentParser(usage=usage)
    argparser.add_argument('-d', '--debug', dest='debug', action='store_true',
                           help='Show debug information about each commanline')
    argparser.add_argument('-v', '--version', dest='version', action='store_true',
                           help='Report version and exit')
    argparser.add_argument('-f', '--full', dest='full', action='store_true',
                           help='Report EVERY items regardless of show=False Flag')
    argparser.add_argument('-q', '--quiet', dest='quiet', action='store_true',
                           help='Quiet mode: do not show output in stdout        ')
    argparser.add_argument('-n', '--dry-run', dest='dryrun', action='store_true',
                           help='Dry Run: Just show commands list                ')
    argparser.add_argument('-p', '--perftest', dest='perftest', action='store_true',
                           help='Perf Test: Run Perftest - /root/system_info/{mkl,stream} ')
    argparser.add_argument('-s', '--since',
                           help='Journalctl --since "1mounths ago" : or --since $(date -I --date \'10days ago\' ) ')

    args = argparser.parse_args()
    debug = False
    pversion = False
    full = False
    quiet = False
    dryrun = False
    perftest = False
    since    = ''
    if args.version:
        pversion = args.version
    if args.debug:
        debug = args.debug
    if args.full:
        full = args.full
    if args.quiet:
        quiet = args.quiet
    if args.dryrun:
        dryrun = args.dryrun
    if args.perftest:
        perftest = args.perftest
    if args.since:
        print(f'--since arg = {args.since}')
        since = args.since

    return debug, pversion, full, quiet, dryrun, perftest, since


def Journalsince(since, key, kconf):
    """Journalsince
    # Journalsince:  Replace Default '1week ago' to argument since
    # Default cmd:   "journalctl  -a  --since '1week ago' --no-pager"
    """
    for litm in kconf[key]:
        if ( 'journalctl' in litm['name'] ) :
            str1 = litm['exe']
            litm['exe'] = str1.replace('1week ago', since )

    return True

def SWPerftest(key, kconf):
    """SWPerftest
    # SWPerftest: 'show' : True  (Enable perftest_xxx)
    """
    for litm in kconf[key]:
        if ( 'perftest' in litm['name'] ) : litm['show']=True

    return True

def Dryrun(key, kconf):
    """Dryrun
    # Dry Run: Just show commands list
    """
    icnt = 1
    for litm in kconf[key]:
        print(icnt, litm['name'], litm['exe'], litm['chk'], litm['show'])
        icnt = icnt + 1

    return True


def StatlistExec(debug, full, quiet, key, kconf):
    """StatlistExec
    # 
    # litm['name'], litm['exe'], litm['chk'], litm['show']
    # 
    """
    import datetime
    import os
    import subprocess
    import shutil
    import time

    icnt = 0
    hname = '%s' % os.uname()[1]
    dt_now = datetime.datetime.now()
    tmpf = '{0}_systeminfo_{1}.txt'.format(hname, dt_now.strftime('%Y%m%d_%H%M%S'))
    logtee = ' 2>&1 | tee -a {0}'.format(tmpf)
    if quiet:
        logtee = ' >> {0} 2>&1 ; echo -n ". "'.format(tmpf)

    my_env = os.environ.copy()
    my_env["LC_ALL"] = "en_US.utf-8"

    TIMEOUT_SEC = 90

    # コマンド実行時間記録用リスト
    exec_times = []

    subprocess.run('(date; /usr/bin/hostnamectl)' + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
    for litm in kconf[key]:
        icnt = icnt + 1
        showsw = litm['show']
        if full:
            showsw = True
        if showsw:
            if debug:
                lstr = '\n:::EL7:::     {0} . . . . No.{1} ({2})\n'.format(litm['name'], icnt, litm['exe'])
            else:
                lstr = '\n:::EL7:::     {0}\n    CMD: {1}\n'.format(litm['name'], litm['exe'])

            if not os.path.exists(litm['chk']):
                warn = '\n   WARN ! : No such file "{0}"\n'.format(litm['chk'])
                exlist = litm['exe'].split(' ')
                cname = exlist[0].split('/')[-1]
                cmd = shutil.which(cname)

                if cmd is None or 'sed' == cname or 'grep' == cname or 'cat' == cname or 'ls' == cname:
                    subprocess.run('echo "{0}"'.format(lstr) + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
                    subprocess.run('echo "{0}"'.format(warn) + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
                else:
                    for ii in range(len(exlist)):
                        if ii > 0:
                            cmd += ' ' + exlist[ii]
                    subprocess.run('echo "{0}"'.format(lstr) + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
                    # 時間計測開始
                    start = time.time()
                    try:
                        subprocess.run(cmd + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
                    except subprocess.TimeoutExpired:
                        pass
                    end = time.time()
                    exec_times.append((cmd, end - start))
            else:
                subprocess.run('echo "{0}"'.format(lstr) + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
                # 時間計測開始
                start = time.time()
                try:
                    subprocess.run(litm['exe'] + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
                except subprocess.TimeoutExpired:
                    pass
                end = time.time()
                exec_times.append((litm['exe'], end - start))

    lstr = '\n:::EL7::: Finished'
    subprocess.run('echo "{0}"'.format(lstr) + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
    subprocess.run('date' + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)
    subprocess.run('echo ""', shell=True, env=my_env, timeout=TIMEOUT_SEC)

    # 所要時間一覧を出力（ファイルへリダイレクト）
    # 所要時間で降順ソート
    exec_times_sorted = sorted(exec_times, key=lambda x: x[1], reverse=True)

    summary_lines = []
    summary_lines.append("\n--- CMD Time Summary (sorted by time desc) ---")
    for idx, (cmd, sec) in enumerate(exec_times_sorted, 1):
        if sec > 0.01 :
            summary_lines.append(f"{idx:03d}: {cmd[:50]:50s}  : {sec:.4f} sec")
    summary_text = "\n".join(summary_lines)

    # ログファイルへリダイレクト
    subprocess.run(f'echo "{summary_text}"' + logtee, shell=True, env=my_env, timeout=TIMEOUT_SEC)

    print(tmpf)
    return


def StatlistImport(debug, statlistfile):
    """StatlistImport
    #
    #    Import kconf from statlistfile
    #
    """
    try:
        # from statlistfile import kconf
        symbol = statlistfile.split('.')[0]
        (file, path, description) = imp.find_module(symbol)
        km = imp.load_module(symbol, file, path, description)
        kconf = km.kconf

    except ImportError:
        print('\n ERROR(80) : "{0}" : Can not import module \n'.format(statlistfile))
        return None

    return kconf


def StatlistImportin(debug):
    """StatlistImportin
    #
    #    Define kconf 
    #
    """
    kconf = dict(sysstatlist=[
        {"name": "os-release", "show": True, "exe": "cat /etc/os-release", "chk": "/etc/os-release"},
        {"name": "redhat-release", "show": True, "exe": "cat /etc/redhat-release", "chk": "/etc/redhat-release"},
        {"name": "lsb-release   ", "show": True, "exe": "cat /etc/lsb-release", "chk": "/etc/lsb-release"},
        {"name": "lsb-release-a ", "show": True, "exe": "/usr/bin/lsb_release -a", "chk": "/usr/bin/lsb_release"},
        {"name": "hostname      ", "show": True, "exe": "cat /etc/hostname", "chk": "/etc/hostname"},
        {"name": "hostnamectl   ", "show": True, "exe": "/usr/bin/hostnamectl", "chk": "/usr/bin/hostnamectl"},
        {"name": "localectl     ", "show": True, "exe": "/usr/bin/localectl", "chk": "/usr/bin/localectl"},
        {"name": "uptime        ", "show": True, "exe": "/usr/bin/uptime", "chk": "/usr/bin/uptime"},
        {"name": "vsmpversion   ", "show": True, "exe": "/usr/local/bin/vsmpversion",
         "chk": "/usr/local/bin/vsmpversion"},
        {"name": "vsmpversion-lg", "show": True, "exe": "/usr/local/bin/vsmpversion --long",
         "chk": "/usr/local/bin/vsmpversion"},
        {"name": "vsmpctl       ", "show": True, "exe": "vsmpctl --status", "chk": "/usr/local/bin/vsmpversion"},
        {"name": "date          ", "show": True, "exe": "/bin/date", "chk": "/bin/date"},
        {"name": "chrony-track  ", "show": True, "exe": "/usr/bin/chronyc tracking -v", "chk": "/usr/bin/chronyc"},
        {"name": "chronyc       ", "show": True, "exe": "/usr/bin/chronyc sources -v", "chk": "/usr/bin/chronyc"},
        {"name": "chronyc-stat  ", "show": True, "exe": "/usr/bin/chronyc sourcestats -v", "chk": "/usr/bin/chronyc"},
        {"name": "chrony.conf   ", "show": True, "exe": "cat /etc/chrony.conf", "chk": "/etc/chrony.conf"},
        {"name": "ntp.conf      ", "show": True, "exe": "cat /etc/ntp.conf", "chk": "/etc/ntp.conf"},
        {"name": "ntpq          ", "show": True, "exe": "/usr/bin/ntpq -np", "chk": "/usr/bin/ntpq"},
        {"name": "xorg.conf     ", "show": True, "exe": "cat /etc/X11/xorg.conf", "chk": "/etc/X11/xorg.conf"},
        {"name": "timedatectl   ", "show": True, "exe": "/usr/bin/timedatectl", "chk": "/usr/bin/timedatectl"},
        {"name": "adjtime       ", "show": True, "exe": "cat /etc/adjtime", "chk": "/etc/adjtime"},
        {"name": "hwclock       ", "show": True, "exe": "/usr/sbin/hwclock --show", "chk": "/usr/sbin/hwclock"},
        {"name": "hwclock-utc   ", "show": True, "exe": "/usr/sbin/hwclock --show --utc", "chk": "/usr/sbin/hwclock"},
        {"name": "hwclock-local ", "show": True, "exe": "/usr/sbin/hwclock --show --localtime",
         "chk": "/usr/sbin/hwclock"},
        {"name": "resolv.conf   ", "show": True, "exe": "cat /etc/resolv.conf", "chk": "/etc/resolv.conf"},
        {"name": "resolvectl    ", "show": True, "exe": "resolvectl status", "chk": "/usr/bin/resolvectl"},
        {"name": "locale        ", "show": True, "exe": "/usr/bin/locale", "chk": "/usr/bin/locale"},
        {"name": "nsswitch.conf ", "show": True, "exe": "cat /etc/nsswitch.conf", "chk": "/etc/nsswitch.conf"},
        {"name": "sestatus      ", "show": True, "exe": "/usr/sbin/sestatus", "chk": "/usr/sbin/sestatus"},
        {"name": "selinux       ", "show": True, "exe": "cat /etc/sysconfig/selinux", "chk": "/etc/sysconfig/selinux"},
        {"name": "getenforce    ", "show": True, "exe": "/usr/sbin/getenforce", "chk": "/usr/sbin/getenforce"},
        {"name": "uname         ", "show": True, "exe": "/bin/uname -a", "chk": "/bin/uname"},
        {"name": "ulimit        ", "show": True, "exe": "ulimit -a", "chk": "/bin/bash"},
        {"name": "env           ", "show": True, "exe": "/usr/bin/env", "chk": "/usr/bin/env"},
        {"name": "shopt         ", "show": True, "exe": "shopt", "chk": "/bin/bash"},
        {"name": "free-g        ", "show": True, "exe": "/usr/bin/free -g", "chk": "/usr/bin/free"},
        {"name": "free          ", "show": True, "exe": "/usr/bin/free   ", "chk": "/usr/bin/free"},
        {"name": "df_ht         ", "show": True, "exe": "/bin/df -hT ", "chk": "/bin/df"},
        {"name": "df_hta        ", "show": True, "exe": "/bin/df -hTa", "chk": "/bin/df"},
        {"name": "mount         ", "show": True, "exe": "/bin/mount", "chk": "/bin/mount"},
        {"name": "proc_mount    ", "show": True, "exe": "cat /proc/mounts", "chk": "/proc/mounts"},
        {"name": "hosts         ", "show": True, "exe": "cat /etc/hosts", "chk": "/etc/hosts"},
        {"name": "fstab         ", "show": True, "exe": "cat /etc/fstab", "chk": "/etc/fstab"},
        {"name": "passwd        ", "show": True, "exe": "cat /etc/passwd", "chk": "/etc/passwd"},
        {"name": "group         ", "show": True, "exe": "cat /etc/group ", "chk": "/etc/group"},
        {"name": "exports       ", "show": True, "exe": "cat /etc/exports", "chk": "/etc/exports"},
        {"name": "exportfs_v    ", "show": True, "exe": "/usr/sbin/exportfs -v", "chk": "/usr/sbin/exportfs"},
        {"name": "nfsstat_all   ", "show": True, "exe": "/usr/sbin/nfsstat -o all", "chk": "/usr/sbin/nfsstat"},
        {"name": "nfsstat_l     ", "show": True, "exe": "/usr/sbin/nfsstat -l", "chk": "/usr/sbin/nfsstat"},
        {"name": "ldconfig      ", "show": False, "exe": "/sbin/ldconfig -v", "chk": "/sbin/ldconfig"},
        {"name": "xfsinfo_root  ", "show": True, "exe": "/usr/sbin/xfs_info /", "chk": "/usr/sbin/xfs_info"},
        {"name": "xfsinfo_boot  ", "show": True, "exe": "/usr/sbin/xfs_info /boot", "chk": "/usr/sbin/xfs_info"},
        {"name": "limits.conf   ", "show": True, "exe": "cat /etc/security/limits.conf",
         "chk": "/etc/security/limits.conf"},
        {"name": "mdadm.conf    ", "show": True, "exe": "cat /etc/mdadm.conf", "chk": "/etc/mdadm.conf"},
        {"name": "proc_mdstat   ", "show": True, "exe": "cat /proc/mdstat", "chk": "/proc/mdstat"},
        {"name": "mdadm_platform", "show": True, "exe": "/sbin/mdadm --detail-platform", "chk": "/proc/mdstat"},
        {"name": "mdadm_md0     ", "show": True, "exe": "/sbin/mdadm --detail /dev/md0", "chk": "/dev/md0"},
        {"name": "mdadm_md125   ", "show": True, "exe": "/sbin/mdadm --detail /dev/md125", "chk": "/dev/md125"},
        {"name": "mdadm_md126   ", "show": True, "exe": "/sbin/mdadm --detail /dev/md126", "chk": "/dev/md126"},
        {"name": "mdadm_md127   ", "show": True, "exe": "/sbin/mdadm --detail /dev/md127", "chk": "/dev/md127"},
        {"name": "mdadm_md126E  ", "show": True, "exe": "/sbin/mdadm --E /dev/md126", "chk": "/dev/md126"},
        {"name": "mdadm_md127E  ", "show": True, "exe": "/sbin/mdadm --E /dev/md127", "chk": "/dev/md127"},
        {"name": "ls-boot       ", "show": True, "exe": "find /boot -maxdepth 2 -type d -ls", "chk": "/bin/true"},
        {"name": "ls-root       ", "show": True, "exe": "find /root -maxdepth 2 -type d -ls", "chk": "/bin/true"},
        {"name": "ls-home       ", "show": True, "exe": "find /home -maxdepth 2 -type d -ls", "chk": "/bin/true"},
        {"name": "ls-crash      ", "show": True, "exe": "find /var/crash/ -type f -ls"      , "chk": "/bin/true"},
        {"name": "abrt-cli-list ", "show": True, "exe": "abrt-cli -d list"                  , "chk": "/usr/bin/abrt-cli"},
        {"name": "lscgroup      ", "show": True, "exe": "/bin/lscgroup", "chk": "/bin/lscgroup"},
        {"name": "systemd-cgls  ", "show": True, "exe": "/usr/bin/systemd-cgls --all -k --no-pager",
         "chk": "/usr/bin/systemd-cgls"},
        {"name": "tree-cgroup   ", "show": True, "exe": "tree -f -L 4 /sys/fs/cgroup", "chk": "/sys/fs/cgroup"},
        {"name": "cgconfig.conf ", "show": True, "exe": "cat /etc/cgconfig.conf", "chk": "/etc/cgconfig.conf"},
        {"name": "cgsnapshot    ", "show": True, "exe": "cgsnapshot", "chk": "/bin/true"},
        {"name": "proc_uptime   ", "show": True, "exe": "cat /proc/uptime ", "chk": "/proc/uptime"},
        {"name": "proc_cmdline  ", "show": True, "exe": "cat /proc/cmdline", "chk": "/proc/cmdline"},
        {"name": "proc_modules  ", "show": True, "exe": "cat /proc/modules", "chk": "/proc/modules"},
        {"name": "proc_slabinfo ", "show": True, "exe": "cat /proc/slabinfo", "chk": "/proc/slabinfo"},
        {"name": "proc_devices  ", "show": True, "exe": "cat /proc/devices", "chk": "/proc/devices"},
        {"name": "proc_swaps    ", "show": True, "exe": "cat /proc/swaps", "chk": "/proc/swaps"},
        {"name": "proc_cgroups  ", "show": True, "exe": "cat /proc/cgroups", "chk": "/proc/cgroups"},
        {"name": "vmstat-swt    ", "show": True, "exe": "vmstat -swt",       "chk": "/proc/vmstat"},
        {"name": "vmstat-awt    ", "show": True, "exe": "vmstat -awt",       "chk": "/proc/vmstat"},
        {"name": "vmstat-mwt    ", "show": True, "exe": "vmstat -mwt",       "chk": "/proc/vmstat"},
        {"name": "vmstat-dwt    ", "show": True, "exe": "vmstat -dwt",       "chk": "/proc/vmstat"},
        {"name": "proc_vmstat   ", "show": True, "exe": "cat /proc/vmstat", "chk": "/proc/vmstat"},
        {"name": "proc_intrpt   ", "show": True, "exe": "cat /proc/interrupts", "chk": "/proc/interrupts"},
        {"name": "proc_zoneinfo ", "show": True, "exe": "cat /proc/zoneinfo", "chk": "/proc/zoneinfo"},
        {"name": "proc_loadavg  ", "show": True, "exe": "cat /proc/loadavg", "chk": "/proc/loadavg"},
        {"name": "proc_part     ", "show": True, "exe": "cat /proc/partitions", "chk": "/proc/partitions"},
        {"name": "proc_buddyinfo", "show": True, "exe": "cat /proc/buddyinfo", "chk": "/proc/buddyinfo"},
        {"name": "proc_cpuinfo  ", "show": True, "exe": "cat /proc/cpuinfo", "chk": "/proc/cpuinfo"},
        {"name": "proc_meminfo  ", "show": True, "exe": "cat /proc/meminfo", "chk": "/proc/meminfo"},
        {"name": "node_meminfo  ", "show": True, "exe": "more /sys/devices/system/node/node*/meminfo", "chk": "/proc/meminfo"},
        {"name": "lsmem_a       ", "show": True, "exe": "/usr/bin/lsmem -a", "chk": "/usr/bin/lsmem"},
        {"name": "lscpu         ", "show": True, "exe": "/usr/bin/lscpu", "chk": "/usr/bin/lscpu"},
        {"name": "lscpu_ae      ", "show": True, "exe": "/usr/bin/lscpu -ae", "chk": "/usr/bin/lscpu"},
        {"name": "cpupower_info ", "show": True, "exe": "/usr/bin/cpupower info", "chk": "/usr/bin/cpupower"},
        {"name": "cpupower_idle ", "show": True, "exe": "/usr/bin/cpupower idle-info", "chk": "/usr/bin/cpupower"},
        {"name": "cpupower_freq ", "show": True, "exe": "/usr/bin/cpupower frequency-info", "chk": "/usr/bin/cpupower"},
        {"name": "cpupower_monit", "show": True, "exe": "/usr/bin/cpupower monitor -i 4", "chk": "/usr/bin/cpupower"},
        {"name": "tuned_log     ", "show": True, "exe": "cat /var/log/tuned/tuned.log",
         "chk": "/var/log/tuned/tuned.log"},
        {"name": "cpuinfo       ", "show": True, "exe": "/root/bin/cpuinfo", "chk": "/root/bin/cpuinfo"},
        {"name": "cpuinfo_a     ", "show": True, "exe": "/root/bin/cpuinfo -A", "chk": "/root/bin/cpuinfo"},
        {"name": "swapon        ", "show": True, "exe": "/sbin/swapon -s", "chk": "/sbin/swapon"},
        {"name": "disk-by-id    ", "show": True, "exe": "ls -g /dev/disk/by-id/", "chk": "/bin/true"},
        {"name": "disk-by-uuid  ", "show": True, "exe": "ls -g /dev/disk/by-uuid/", "chk": "/bin/true"},
        {"name": "lsblk         ", "show": True, "exe": "/usr/bin/lsblk -f ", "chk": "/usr/bin/lsblk"},
        {"name": "lsblk_fs      ", "show": True, "exe": "/usr/bin/lsblk -fs", "chk": "/usr/bin/lsblk"},
        {"name": "lsblk_all     ", "show": True, "exe": "lsblk -a -o NAME,MAJ:MIN,RM,SIZE,RO,TYPE,MODEL,MOUNTPOINT", "chk": "/usr/bin/lsblk"},
        {"name": "blkid         ", "show": True, "exe": "/usr/sbin/blkid", "chk": "/usr/sbin/blkid"},
        {"name": "lsusb         ", "show": True, "exe": "/usr/bin/lsusb", "chk": "/usr/bin/lsusb"},
        {"name": "lsusb-v       ", "show": True, "exe": "/usr/bin/lsusb -v", "chk": "/usr/bin/lsusb"},
        {"name": "lsusb-t       ", "show": True, "exe": "/usr/bin/lsusb -t", "chk": "/usr/bin/lsusb"},
        {"name": "lsscsi        ", "show": True, "exe": "/usr/bin/lsscsi", "chk": "/usr/bin/lsscsi"},
        {"name": "lsscsi-vl     ", "show": True, "exe": "/usr/bin/lsscsi -vl", "chk": "/usr/bin/lsscsi"},
        {"name": "fdisk         ", "show": True, "exe": "/sbin/fdisk -l", "chk": "/sbin/fdisk"},
        {"name": "parted        ", "show": True, "exe": "/sbin/parted -s -l", "chk": "/sbin/parted"},
        {"name": "sfdisk_sda    ", "show": True, "exe": "sfdisk -d /dev/sda", "chk": "/sbin/sfdisk"},
        {"name": "sfdisk_sdb    ", "show": True, "exe": "sfdisk -d /dev/sdb", "chk": "/sbin/sfdisk"},
        {"name": "sfdisk_sdc    ", "show": True, "exe": "sfdisk -d /dev/sdc", "chk": "/sbin/sfdisk"},
        {"name": "sfdisk_nvme0  ", "show": True, "exe": "sfdisk -d /dev/nvme0", "chk": "/sbin/sfdisk"},
        {"name": "sfdisk_nvme0n1", "show": True, "exe": "sfdisk -d /dev/nvme0n1", "chk": "/sbin/sfdisk"},
        {"name": "findmnt       ", "show": True, "exe": "findmnt",              "chk": "/usr/bin/findmnt"},
        {"name": "findmnt_l     ", "show": True, "exe": "findmnt -l",           "chk": "/usr/bin/findmnt"},
        {"name": "smart_sda     ", "show": True, "exe": "/usr/sbin/smartctl -a /dev/sda", "chk": "/dev/sda"},
        {"name": "smart_sdb     ", "show": True, "exe": "/usr/sbin/smartctl -a /dev/sdb", "chk": "/dev/sdb"},
        {"name": "smart_sdc     ", "show": True, "exe": "/usr/sbin/smartctl -a /dev/sdc", "chk": "/dev/sdc"},
        {"name": "smart_nvme0   ", "show": True, "exe": "/usr/sbin/smartctl -a /dev/nvme0", "chk": "/dev/nvme0"},
        {"name": "smart_nvme0n1 ", "show": True, "exe": "/usr/sbin/smartctl -a /dev/nvme0n1", "chk": "/dev/nvme0n1"},
        {"name": "pvscan        ", "show": True, "exe": "/sbin/pvscan", "chk": "/sbin/pvscan"},
        {"name": "vgscan        ", "show": True, "exe": "/sbin/vgscan", "chk": "/sbin/vgscan"},
        {"name": "lvscan        ", "show": True, "exe": "/sbin/lvscan", "chk": "/sbin/lvscan"},
        {"name": "pvdisplay     ", "show": True, "exe": "/sbin/pvdisplay", "chk": "/sbin/pvdisplay"},
        {"name": "vgdisplay     ", "show": True, "exe": "/sbin/vgdisplay", "chk": "/sbin/vgdisplay"},
        {"name": "lvdisplay     ", "show": True, "exe": "/sbin/lvdisplay", "chk": "/sbin/lvdisplay"},
        {"name": "multipath_l   ", "show": True, "exe": "/sbin/multipath -l", "chk": "/sbin/multipath"},
        {"name": "multipath_ll  ", "show": True, "exe": "/sbin/multipath -ll", "chk": "/sbin/multipath"},
        {"name": "dmsetup_info  ", "show": True, "exe": "/sbin/dmsetup info", "chk": "/sbin/dmsetup"},
        {"name": "dmsetup_ls    ", "show": True, "exe": "/sbin/dmsetup ls --tree", "chk": "/sbin/dmsetup"},
        {"name": "check_UEFI    ", "show": True, "exe": "ls -g /sys/firmware/efi/", "chk": "/sys/firmware/efi"},
        {"name": "efibootmgr    ", "show": True, "exe": "/usr/sbin/efibootmgr", "chk": "/usr/sbin/efibootmgr"},
        {"name": "efibootmgr_v  ", "show": True, "exe": "/usr/sbin/efibootmgr -v", "chk": "/usr/sbin/efibootmgr"},
        {"name": "ibdiagnet     ", "show": True, "exe": "/usr/bin/ibdiagnet", "chk": "/usr/bin/ibdiagnet"},
        {"name": "ibstat        ", "show": True, "exe": "/usr/sbin/ibstat", "chk": "/usr/sbin/ibstat"},
        {"name": "ibstatus      ", "show": True, "exe": "/usr/sbin/ibstatus", "chk": "/usr/sbin/ibstatus"},
        {"name": "iblinkinfo_l  ", "show": True, "exe": "/usr/sbin/iblinkinfo -l", "chk": "/usr/sbin/iblinkinfo"},
        {"name": "ibv_devices   ", "show": True, "exe": "/usr/bin/ibv_devices -v", "chk": "/usr/bin/ibv_devices"},
        {"name": "ibv_devinfo_v ", "show": True, "exe": "/usr/bin/ibv_devinfo -v", "chk": "/usr/bin/ibv_devinfo"},
        {"name": "hca_self_test ", "show": True, "exe": "/usr/bin/hca_self_test.ofed",
         "chk": "/usr/bin/hca_self_test.ofed"},
        {"name": "ofed_info     ", "show": True, "exe": "/usr/bin/ofed_info", "chk": "/usr/bin/ofed_info"},
        {"name": "perfquery     ", "show": True, "exe": "/usr/sbin/perfquery -x", "chk": "/usr/sbin/perfquery"},
        {"name": "ibnetdiscover ", "show": True, "exe": "/usr/sbin/ibnetdiscover -l", "chk": "/usr/sbin/ibnetdiscover"},
        {"name": "ibnetdiscoverf", "show": True, "exe": "/usr/sbin/ibnetdiscover --full",
         "chk": "/usr/sbin/ibnetdiscover"},
        {"name": "dmidecode     ", "show": True, "exe": "/usr/sbin/dmidecode",  "chk": "/usr/sbin/dmidecode"},
        {"name": "biosdecode    ", "show": True, "exe": "/usr/sbin/biosdecode", "chk": "/usr/sbin/biosdecode"},
        {"name": "biosdevname-d ", "show": True, "exe": "biosdevname -d",       "chk": "/usr/sbin/biosdevname"},
        {"name": "sysclassdmi   ", "show": True, "exe": "grep . /sys/class/dmi/id/*", "chk": "/sys/class/dmi/id"},
        {"name": "vulnerabilities", "show": True, "exe": "grep . /sys/devices/system/cpu/vulnerabilities/*", "chk": "/sys/devices/system/cpu/vulnerabilities"},
        {"name": "lshw          ", "show": True, "exe": "/usr/sbin/lshw -numeric", "chk": "/usr/sbin/lshw"},
        {"name": "inxi_F        ", "show": True, "exe": "/usr/bin/inxi -a -FrmxxZ -c 0 -S --sleep 1.0 -y 120", "chk": "/usr/bin/inxi"},
        {"name": "systool_dmi   ", "show": True, "exe": "/usr/bin/systool -c dmi -v", "chk": "/usr/bin/systool"},
        {"name": "systool_block ", "show": True, "exe": "/usr/bin/systool -c block -d -v", "chk": "/usr/bin/systool"},
        {"name": "systool_net   ", "show": True, "exe": "/usr/bin/systool -c net -v", "chk": "/usr/bin/systool"},
        {"name": "numactl_show  ", "show": True, "exe": "/usr/bin/numactl --show", "chk": "/usr/bin/numactl"},
        {"name": "numactl_hdw   ", "show": True, "exe": "/usr/bin/numactl --hardware", "chk": "/usr/bin/numactl"},
        {"name": "numastat      ", "show": True, "exe": "/usr/bin/numastat -m",     "chk": "/usr/bin/numastat"},
        {"name": "sys_pci_bus   ", "show": True, "exe": "ls -g /sys/class/pci_bus", "chk": "/sys/class/pci_bus"},
        {"name": "sys_nodenode  ", "show": True, "exe": "ls -g /sys/devices/system/node/node*",
         "chk": "/sys/devices/system/node"},
        {"name": "sys_net       ", "show": True, "exe": "ls -g /sys/class/net", "chk": "/sys/class/net"},
        {"name": "sys_net_stat  ", "show": True, "exe": "grep . /sys/class/net/*/statistics/*",
         "chk": "/sys/class/net"},
        {"name": "netplan_status", "show": True, "exe": "netplan status", "chk": "/etc/netplan"},
        {"name": "netplan       ", "show": True, "exe": "cat /etc/netplan/00-installer-config.yaml", "chk": "/etc/netplan"},
        {"name": "nmcli         ", "show": True, "exe": "/usr/bin/nmcli", "chk": "/usr/bin/nmcli"},
        {"name": "nmcli_device  ", "show": True, "exe": "/usr/bin/nmcli device", "chk": "/usr/bin/nmcli"},
        {"name": "nmcli_conn    ", "show": True, "exe": "/usr/bin/nmcli connection", "chk": "/usr/bin/nmcli"},
        {"name": "nmcli_d_show  ", "show": True, "exe": "/usr/bin/nmcli device show", "chk": "/usr/bin/nmcli"},
        {"name": "rpcinfo-p     ", "show": True, "exe": "/usr/sbin/rpcinfo -p", "chk": "/usr/sbin/rpcinfo"},
        {"name": "rpcinfo-s     ", "show": True, "exe": "/usr/sbin/rpcinfo -s", "chk": "/usr/sbin/rpcinfo"},
        {"name": "netstat-i     ", "show": True, "exe": "/bin/netstat -i", "chk": "/bin/netstat"},
        {"name": "netstat-rn    ", "show": True, "exe": "/bin/netstat -rn", "chk": "/bin/netstat"},
        {"name": "netstat-tulpn ", "show": True, "exe": "/bin/netstat -tulpn", "chk": "/bin/netstat"},
        {"name": "netstat-anp   ", "show": True, "exe": "/bin/netstat -anp", "chk": "/bin/netstat"},
        {"name": "netstat-s     ", "show": True, "exe": "/bin/netstat -s", "chk": "/bin/netstat"},
        {"name": "ifstat        ", "show": True, "exe": "/sbin/ifstat", "chk": "/sbin/ifstat"},
        {"name": "ifconfig      ", "show": True, "exe": "/sbin/ifconfig", "chk": "/sbin/ifconfig"},
        {"name": "ifconfig-a    ", "show": True, "exe": "/sbin/ifconfig -a", "chk": "/sbin/ifconfig"},
        {"name": "ip_link       ", "show": True, "exe": "/sbin/ip link", "chk": "/sbin/ip"},
        {"name": "ip_link_s     ", "show": True, "exe": "/sbin/ip -s link", "chk": "/sbin/ip"},
        {"name": "ip_route      ", "show": True, "exe": "/sbin/ip route show table all", "chk": "/sbin/ip"},
        {"name": "ip_tunnel     ", "show": True, "exe": "/sbin/ip tunnel", "chk": "/sbin/ip"},
        {"name": "ip_addr       ", "show": True, "exe": "/sbin/ip address list", "chk": "/sbin/ip"},
        {"name": "ip_maddr      ", "show": True, "exe": "/sbin/ip maddr", "chk": "/sbin/ip"},
        {"name": "ip_neigh      ", "show": True, "exe": "/sbin/ip neigh", "chk": "/sbin/ip"},
        {"name": "iptable       ", "show": True, "exe": "/sbin/iptables -nv -L", "chk": "/sbin/iptables"},
        {"name": "iptable-nat   ", "show": True, "exe": "/sbin/iptables -t nat -L -n -v", "chk": "/sbin/iptables"},
        {"name": "arp-ave       ", "show": True, "exe": "/sbin/arp -aev"  , "chk": "/sbin/arp"},
        {"name": "arp-aven      ", "show": True, "exe": "/sbin/arp -aevn" , "chk": "/sbin/arp"},
        {"name": "firewall-all  ", "show": True, "exe": "/usr/bin/firewall-cmd --list-all",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-zone ", "show": True, "exe": "/usr/bin/firewall-cmd --list-all-zones",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-svcs ", "show": True, "exe": "/usr/bin/firewall-cmd --list-services",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-port ", "show": True, "exe": "/usr/bin/firewall-cmd --list-ports",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-ifce ", "show": True, "exe": "/usr/bin/firewall-cmd --list-interfaces",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-srce ", "show": True, "exe": "/usr/bin/firewall-cmd --list-sources",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-chain", "show": True, "exe": "/usr/bin/firewall-cmd --direct --get-all-chains",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-rule ", "show": True, "exe": "/usr/bin/firewall-cmd --direct --get-all-rules",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "firewall-pass ", "show": True, "exe": "/usr/bin/firewall-cmd --direct --get-all-passthroughs",
         "chk": "/usr/bin/firewall-cmd"},
        {"name": "ss-an4        ", "show": True, "exe": "/usr/sbin/ss -an4", "chk": "/usr/sbin/ss"},
        {"name": "ss-an4p       ", "show": True, "exe": "/usr/sbin/ss -an4p", "chk": "/usr/sbin/ss"},
        {"name": "ss-tu         ", "show": True, "exe": "/usr/sbin/ss -tu", "chk": "/usr/sbin/ss"},
        {"name": "ss-tuln       ", "show": True, "exe": "/usr/sbin/ss -tuln", "chk": "/usr/sbin/ss"},
        {"name": "ss-p          ", "show": True, "exe": "/usr/sbin/ss -p ", "chk": "/usr/sbin/ss"},
        {"name": "ss-aALL       ", "show": True, "exe": "/usr/sbin/ss -A all ", "chk": "/usr/sbin/ss"},
        {"name": "lsmod         ", "show": True, "exe": "/sbin/lsmod", "chk": "/sbin/lsmod"},
        {"name": "modinfo_mlx4  ", "show": True, "exe": "/sbin/modinfo mlx4_core", "chk": "/sbin/modinfo"},
        {"name": "modinfo_mlx5  ", "show": True, "exe": "/sbin/modinfo mlx5_core", "chk": "/sbin/modinfo"},
        {"name": "modinfo_ixgbe ", "show": True, "exe": "/sbin/modinfo ixgbe", "chk": "/sbin/modinfo"},
        {"name": "modinfo_bnx2x ", "show": True, "exe": "/sbin/modinfo bnx2x", "chk": "/sbin/modinfo"},
        {"name": "modinfo_megasr", "show": True, "exe": "/sbin/modinfo megasr", "chk": "/sbin/modinfo"},
        {"name": "modinfo_mpt3sa", "show": True, "exe": "/sbin/modinfo mpt3sas", "chk": "/sbin/modinfo"},
        {"name": "modinfo_megara", "show": True, "exe": "/sbin/modinfo megaraid_sas", "chk": "/sbin/modinfo"},
        {"name": "modinfo_ast   ", "show": True, "exe": "/sbin/modinfo ast", "chk": "/sbin/modinfo"},
        {"name": "modprobe.d    ", "show": True, "exe": "grep . /etc/modprobe.d/*", "chk": "/etc/modprobe.d"},
        {"name": "proc_driver   ", "show": True, "exe": "grep . /proc/driver/*", "chk": "/proc/driver"},
        {"name": "sys_parameter ", "show": True, "exe": "grep . /sys/module/*/parameters/* ", "chk": "/sys/module"},
        {"name": "lspci         ", "show": True, "exe": "/sbin/lspci    ", "chk": "/sbin/lspci"},
        {"name": "lspci-vt      ", "show": True, "exe": "/sbin/lspci -vt", "chk": "/sbin/lspci"},
        {"name": "lspci-nnk     ", "show": True, "exe": "/sbin/lspci -nnk", "chk": "/sbin/lspci"},
        {"name": "lspci-vvv     ", "show": True, "exe": "/sbin/lspci -vvv", "chk": "/sbin/lspci"},
        {"name": "sysctl.conf   ", "show": True, "exe": "cat /etc/sysctl.conf", "chk": "/etc/sysctl.conf"},
        {"name": "sysctl-a      ", "show": True, "exe": "/sbin/sysctl -a ", "chk": "/sbin/sysctl"},
        {"name": "sysctl.d      ", "show": True, "exe": "grep . /etc/sysctl.d/*", "chk": "/etc/sysctl.d"},
        {"name": "grub.cfg      ", "show": True, "exe": "cat /boot/grub/grub.cfg", "chk": "/boot/grub/grub.cfg"},
        {"name": "grub2.cfg     ", "show": True, "exe": "cat /boot/grub2/grub.cfg", "chk": "/boot/grub2/grub.cfg"},
        {"name": "grub2.cfg-cent", "show": True, "exe": "cat /boot/efi/EFI/centos/grub.cfg", "chk": "/boot/efi/EFI/centos/grub.cfg"},
        {"name": "grub2.cfg-rhel", "show": True, "exe": "cat /boot/efi/EFI/redhat/grub.cfg", "chk": "/boot/efi/EFI/redhat/grub.cfg"},
        {"name": "grub2.cfg-rock", "show": True, "exe": "cat /boot/efi/EFI/rocky/grub.cfg", "chk": "/boot/efi/EFI/rocky/grub.cfg"},
        {"name": "etc-grub      ", "show": True, "exe": "cat /etc/default/grub"  , "chk": "/etc/default/grub"},
        {"name": "grubby-index  ", "show": True, "exe": "grubby --default-index" , "chk": "/etc/default/grub"},
        {"name": "grubby-kernel ", "show": True, "exe": "grubby --default-kernel", "chk": "/etc/default/grub"},
        {"name": "grubby-title  ", "show": True, "exe": "grubby --default-title" , "chk": "/etc/default/grub"},
        {"name": "grubby-all    ", "show": True, "exe": "grubby --info ALL"      , "chk": "/etc/default/grub"},
        {"name": "lsinitrd      ", "show": True, "exe": "lsinitrd /boot/initramfs-$(uname -r).img" , "chk": "/bin/true"},
        {"name": "yum-history   ", "show": True, "exe": "/usr/bin/yum --noplugins history", "chk": "/etc/yum.repos.d"},
        {"name": "yum-repolist  ", "show": True, "exe": "/usr/bin/yum --noplugins repolist all", "chk": "/etc/yum.repos.d"},
        {"name": "yum-repofiles ", "show": True, "exe": "grep . /etc/yum.repos.d/*", "chk": "/etc/yum.repos.d"},
        {"name": "yum-list      ", "show": True, "exe": "/usr/bin/yum list", "chk": "/etc/yum.repos.d"},
        {"name": "yum-grouplist ", "show": True, "exe": "/usr/bin/yum -v grouplist hidden", "chk": "/etc/yum.repos.d"},
        {"name": "yum-history   ", "show": True, "exe": "/usr/bin/yum history"            , "chk": "/etc/yum.repos.d"},
        {"name": "chkconfig     ", "show": True, "exe": "/sbin/chkconfig --list", "chk": "/etc/chkconfig.d"},
        {"name": "service-stat  ", "show": True, "exe": "/sbin/service --status-all", "chk": "/etc/init.d"},
        {"name": "list-units    ", "show": True, "exe": "/usr/bin/systemctl --no-pager list-units", "chk": "/bin/true"},
        {"name": "list-unit-file", "show": True, "exe": "/usr/bin/systemctl --no-pager list-unit-files", "chk": "/bin/true"},
        {"name": "systemctl-all ", "show": True, "exe": "/usr/bin/systemctl --no-pager --all", "chk": "/bin/true"},
        {"name": "systemctl-fail", "show": True, "exe": "/usr/bin/systemctl --no-pager --failed", "chk": "/bin/true"},
        {"name": "systemctl-stat", "show": True, "exe": "/usr/bin/systemctl --no-pager status", "chk": "/bin/true"},
        {"name": "systemctl-jobs", "show": True, "exe": "/usr/bin/systemctl --no-pager list-jobs", "chk": "/bin/true"},
        {"name": "analyze-time  ", "show": True, "exe": "/usr/bin/systemd-analyze time", "chk": "/bin/true"},
        {"name": "analyze-blame ", "show": True, "exe": "/usr/bin/systemd-analyze --system --no-pager blame",
         "chk": "/bin/true"},
        {"name": "analyze-critc ", "show": True, "exe": "/usr/bin/systemd-analyze --system --no-pager critical-chain",
         "chk": "/bin/true"},
        {"name": "rpm-qa-last   ", "show": True, "exe": "/bin/rpm -qa --last", "chk": "/bin/true"},
        {"name": "dpkg-l        ", "show": True, "exe": "/usr/bin/dpkg --no-pager -l", "chk": "/var/log/dpkg.log"},
        {"name": "dpkg-install  ", "show": True, "exe": "zgrep 'status installed' /var/log/dpkg.log*", "chk": "/var/log/dpkg.log"},
        {"name": "ls-Xorg.0.log ", "show": True, "exe": "ls -l /var/log/Xorg.0.log", "chk": "/var/log/Xorg.0.log"},
        {"name": "Xorg.0.log    ", "show": True, "exe": "cat -n  /var/log/Xorg.0.log", "chk": "/var/log/Xorg.0.log"},
        {"name": "ls-audit.log  ", "show": True, "exe": "ls -l /var/log/audit/audit.log",
         "chk": "/var/log/audit/audit.log"},
        {"name": "audit.log     ", "show": True, "exe": "cat -n  /var/log/audit/audit.log",
         "chk": "/var/log/audit/audit.log"},
        {"name": "ls-boot.log   ", "show": True, "exe": "ls -l /var/log/boot.log", "chk": "/var/log/boot.log"},
        {"name": "boot.log      ", "show": True,
         "exe": "sed -r -e 's/.$//' -e 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})*)?m//g' /var/log/boot.log",
         "chk": "/var/log/boot.log"},
        {"name": "dmesg         ", "show": True, "exe": "/bin/dmesg", "chk": "/bin/true"},
        {"name": "ls-mcelog     ", "show": True, "exe": "ls -g /var/log/mcelog", "chk": "/var/log/mcelog"},
        {"name": "mcelog        ", "show": True, "exe": "cat   /var/log/mcelog", "chk": "/var/log/mcelog"},
        {"name": "syslog        ", "show": True, "exe": "cat   /var/log/syslog", "chk": "/var/log/syslog"},
        {"name": "secure        ", "show": True, "exe": "cat   /var/log/secure", "chk": "/var/log/secure"},
        {"name": "opensm.log    ", "show": True, "exe": "cat   /var/log/opensm.log", "chk": "/var/log/opensm.log"},
        {"name": "messages      ", "show": True,
         "exe": "ls -1 /var/log/messages* | xargs -i bash -c 'echo ; echo :::EL7:::  {}; cat {}'",
         "chk": "/var/log/messages"},
        {"name": "journal-boots ", "show": True, "exe": "journalctl --list-boots --no-pager", "chk": "/usr/bin/journalctl"},
        {"name": "journalctl    ", "show": True, "exe": "journalctl  -a  --since '1week ago' --no-pager", "chk": "/usr/bin/journalctl"},
        {"name": "ps-forest-e   ", "show": True, "exe": "ps --forest -e", "chk": "/bin/true"},
        {"name": "ps-auxw-forest", "show": True, "exe": "ps auxw --forest -e", "chk": "/bin/true"},
        {"name": "ps-edalfL     ", "show": True, "exe": "ps -edalfL", "chk": "/bin/true"},
        {"name": "ps-efww       ", "show": True, "exe": "ps -efww", "chk": "/bin/true"},
        {"name": "ps-auxfww     ", "show": True, "exe": "ps -auxfww", "chk": "/bin/true"},
        {"name": "lsof-i        ", "show": True, "exe": "/usr/bin/lsof -i", "chk": "/usr/bin/lsof"},
        {"name": "lsof-inP      ", "show": True, "exe": "/usr/bin/lsof -i -n -P", "chk": "/usr/bin/lsof"},
        {"name": "ipmi-mcinfo   ", "show": True, "exe": "/usr/bin/ipmitool mc info", "chk": "/dev/ipmi0"},
        {"name": "ipmi-fru      ", "show": True, "exe": "/usr/bin/ipmitool fru", "chk": "/dev/ipmi0"},
        {"name": "ipmi-lan      ", "show": True, "exe": "/usr/bin/ipmitool lan print", "chk": "/dev/ipmi0"},
        {"name": "ipmi-lan8     ", "show": True, "exe": "/usr/bin/ipmitool lan print 8", "chk": "/dev/ipmi0"},
        {"name": "ipmi-time     ", "show": True, "exe": "/usr/bin/ipmitool sel time get", "chk": "/dev/ipmi0"},
        {"name": "ipmi-selinfo  ", "show": True, "exe": "/usr/bin/ipmitool sel info", "chk": "/dev/ipmi0"},
        {"name": "ipmi-selelist ", "show": True, "exe": "/usr/bin/ipmitool sel elist", "chk": "/dev/ipmi0"},
        {"name": "ipmi-sdrelist ", "show": True, "exe": "/usr/bin/ipmitool sdr elist", "chk": "/dev/ipmi0"},
        {"name": "ipmi-sensor   ", "show": True, "exe": "/usr/bin/ipmitool sensor list", "chk": "/dev/ipmi0"},
        {"name": "ipmi-user     ", "show": True, "exe": "/usr/bin/ipmitool user  list 1", "chk": "/dev/ipmi0"},
        {"name": "ifcfg-files   ", "show": True,
         "exe": "ls -1 /etc/sysconfig/network-scripts/ifcfg-* 2>/dev/null | xargs -i bash -c 'echo ; echo :::EL7::: `basename {}`; cat {}'",
         "chk": "/bin/true"},
        {"name": "ls-nmconnections", "show": True, "exe": "ls -g /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null", "chk": "/etc/NetworkManager/system-connections"},
        {"name": "nmconnections ", "show": True,
         "exe": "ls -1 /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null | xargs -i bash -c 'echo ; echo :::EL7::: `basename \"{}\" | sed \"s/ /_/g\"`; cat \"{}\"'", "chk": "/etc/NetworkManager/system-connections"},
        {"name": "network       ", "show": True, "exe": "cat /etc/sysconfig/network", "chk": "/etc/sysconfig/network"},
        {"name": "ifconfig-info ", "show": True,
         "exe": "ls -1 /sys/class/net | egrep -v 'br|lo' | xargs -i bash -c 'echo ; echo :::EL7:::  ifconfig-{}; ifconfig {}'",
         "chk": "/sys/class/net"},
        {"name": "ethtool-info  ", "show": True,
         "exe": "ls -1 /sys/class/net | egrep -v 'br|lo' | xargs -i bash -c 'echo ; echo :::EL7:::  ethtool-{}; ethtool {}'",
         "chk": "/sys/class/net"},
        {"name": "ethtoolI-info  ", "show": True,
         "exe": "ls -1 /sys/class/net | egrep -v 'br|lo' | xargs -i bash -c 'echo ; echo :::EL7:::  ethtoolI-{}; ethtool -i {}'",
         "chk": "/sys/class/net"},
        {"name": "affinity-udevd", "show": True, "exe": "taskset -pc `pidof systemd-udevd`",
         "chk": "/usr/lib/systemd/system/systemd-udevd.service"},
        {"name": "systemd-udevd ", "show": True, "exe": "cat /usr/lib/systemd/system/systemd-udevd.service",
         "chk": "/usr/lib/systemd/system/systemd-udevd.service"},
        {"name": "sarA          ", "show": True, "exe": "sar -A", "chk": "/bin/true"},
        {"name": "StorCli-show  ", "show": True, "exe": "/opt/MegaRAID/storcli/storcli64 /call show all",
         "chk": "/opt/MegaRAID/storcli/storcli64"},
        {"name": "StorCli-showAL", "show": True, "exe": "/opt/MegaRAID/storcli/storcli64 /call/eall/sall show all",
         "chk": "/opt/MegaRAID/storcli/storcli64"},
        {"name": "StorCli-dpdinf", "show": True, "exe": "/opt/MegaRAID/storcli/storcli64 -LdpdInfo -aall",
         "chk": "/opt/MegaRAID/storcli/storcli64"},
        {"name": "StorCli-trmlog", "show": True, "exe": "/opt/MegaRAID/storcli/storcli64 /call show termlog",
         "chk": "/opt/MegaRAID/storcli/storcli64"},
        {"name": "StorCli-events", "show": True, "exe": "/opt/MegaRAID/storcli/storcli64 /call show events",
         "chk": "/opt/MegaRAID/storcli/storcli64"},
        {"name": "MegaCli-summar", "show": True, "exe": "/opt/MegaRAID/MegaCli/MegaCli64 -ShowSummary -aALL",
         "chk": "/opt/MegaRAID/MegaCli/MegaCli64"},
        {"name": "MegaCli-ldinfo", "show": True, "exe": "/opt/MegaRAID/MegaCli/MegaCli64 -LDInfo -Lall -aALL",
         "chk": "/opt/MegaRAID/MegaCli/MegaCli64"},
        {"name": "MegaCli-adpinf", "show": True, "exe": "/opt/MegaRAID/MegaCli/MegaCli64 -AdpAllInfo -aALL",
         "chk": "/opt/MegaRAID/MegaCli/MegaCli64"},
        {"name": "MegaCli-encinf", "show": True, "exe": "/opt/MegaRAID/MegaCli/MegaCli64 -EncInfo -aALL",
         "chk": "/opt/MegaRAID/MegaCli/MegaCli64"},
        {"name": "MegaCli-pdlist", "show": True, "exe": "/opt/MegaRAID/MegaCli/MegaCli64 -PDList -aALL",
         "chk": "/opt/MegaRAID/MegaCli/MegaCli64"},
        {"name": "dmraid-list",      "show": True, "exe": "dmraid -r", "chk": "/sbin/dmraid"},
        {"name": "dmraid-status",    "show": True, "exe": "dmraid -s", "chk": "/sbin/dmraid"},
        {"name": "dmraid-mapper",    "show": True, "exe": "ls -l /dev/mapper", "chk": "/dev/mapper"},
        {"name": "sas3ircu-list",    "show": True, "exe": "sas3ircu list", "chk": "/root/bin/sas3ircu"},
        {"name": "sas3ircu-display", "show": True, "exe": "sas3ircu 0 display", "chk": "/root/bin/sas3ircu"},
        {"name": "sas3ircu-status" , "show": True, "exe": "sas3ircu 0 status", "chk": "/root/bin/sas3ircu"},
        {"name": "smb.conf      ", "show": True, "exe": "cat /etc/samba/smb.conf", "chk": "/etc/samba/smb.conf"},
        {"name": "smbstatus     ", "show": True, "exe": "/usr/bin/smbstatus", "chk": "/etc/samba/smb.conf"},
        {"name": "smbstatus-d4  ", "show": True, "exe": "/usr/bin/smbstatus -d 4", "chk": "/etc/samba/smb.conf"},
        {"name": "pdbedit       ", "show": True, "exe": "/usr/bin/pdbedit -L", "chk": "/etc/samba/smb.conf"},
        {"name": "pdbedit-vl    ", "show": True, "exe": "/usr/bin/pdbedit -v -L", "chk": "/etc/samba/smb.conf"},
        {"name": "hwloc-ver     ", "show": True, "exe": "/usr/bin/hwloc-ls --version", "chk": "/usr/bin/hwloc-ls"},
        {"name": "hwloc-ls      ", "show": True, "exe": "/usr/bin/hwloc-ls", "chk": "/usr/bin/hwloc-ls"},
        {"name": "hwloc-info    ", "show": True, "exe": "/usr/bin/hwloc-info", "chk": "/usr/bin/hwloc-ls"},
        {"name": "torque-pbsnode", "show": True, "exe": "/usr/local/bin/pbsnodes -a", "chk": "/usr/local/bin/pbsnodes"},
        {"name": "torque-momctl ", "show": True, "exe": "/usr/local/sbin/momctl -d 6", "chk": "/usr/local/sbin/momctl"},
        {"name": "torque-qmgr   ", "show": True, "exe": "/usr/local/bin/qmgr -c 'p s'", "chk": "/usr/local/bin/qmgr"},
        {"name": "torque-qstatq ", "show": True, "exe": "/usr/local/bin/qstat -fQ", "chk": "/usr/local/bin/qstat"},
        {"name": "torque-qstatb ", "show": True, "exe": "/usr/local/bin/qstat -fB", "chk": "/usr/local/bin/qstat"},
        {"name": "torque-svrname", "show": True, "exe": "cat /var/spool/torque/server_name",
         "chk": "/var/spool/torque/server_name"},
        {"name": "torque-momcfg ", "show": True, "exe": "cat /var/spool/torque/mom_priv/config",
         "chk": "/var/spool/torque/mom_priv/config"},
        {"name": "torque-svrnode", "show": True, "exe": "cat /var/spool/torque/server_priv/nodes",
         "chk": "/var/spool/torque/server_priv/nodes"},
        {"name": "pbs.conf      ", "show": True, "exe": "cat /etc/pbs.conf", "chk": "/etc/pbs.conf"},
        {"name": "mom_config    ", "show": True, "exe": "cat /var/spool/pbs/mom_priv/config",
         "chk": "/var/spool/pbs/mom_priv/config"},
        {"name": "pbs-pbsnodes  ", "show": True, "exe": "/opt/pbs/bin/pbsnodes -a", "chk": "/opt/pbs/bin/pbsnodes"},
        {"name": "pbs-pbsnodesS ", "show": True, "exe": "/opt/pbs/bin/pbsnodes -aS", "chk": "/opt/pbs/bin/pbsnodes"},
        {"name": "pbs-qmgr_l_s  ", "show": True, "exe": "/opt/pbs/bin/qmgr -c 'l s'", "chk": "/opt/pbs/bin/qmgr"},
        {"name": "pbs-qmgr_p_s  ", "show": True, "exe": "/opt/pbs/bin/qmgr -c 'p s'", "chk": "/opt/pbs/bin/qmgr"},
        {"name": "pbs-qmgr_l_h  ", "show": True, "exe": "/opt/pbs/bin/qmgr -c 'l h'", "chk": "/opt/pbs/bin/qmgr"},
        {"name": "pbs-qstat-q   ", "show": True, "exe": "/opt/pbs/bin/qstat -Q", "chk": "/opt/pbs/bin/qstat"},
        {"name": "pbs-qstat-fq  ", "show": True, "exe": "/opt/pbs/bin/qstat -fQ", "chk": "/opt/pbs/bin/qstat"},
        {"name": "pbs-qstat-b   ", "show": True, "exe": "/opt/pbs/bin/qstat -B", "chk": "/opt/pbs/bin/qstat"},
        {"name": "pbs-qstat-fb  ", "show": True, "exe": "/opt/pbs/bin/qstat -fB", "chk": "/opt/pbs/bin/qstat"},
        {"name": "pbs-qstat-f   ", "show": True, "exe": "/opt/pbs/bin/qstat -f", "chk": "/opt/pbs/bin/qstat"},
        {"name": "gmetad3.conf  ", "show": True, "exe": "cat /etc/gmetad.conf", "chk": "/etc/gmetad.conf"},
        {"name": "gmond3.conf   ", "show": True, "exe": "cat /etc/gmond.conf", "chk": "/etc/gmond.conf"},
        {"name": "gmetad.conf   ", "show": True, "exe": "cat /etc/ganglia/gmetad.conf", "chk": "/etc/ganglia/gmetad.conf"},
        {"name": "gmond.conf    ", "show": True, "exe": "cat /etc/ganglia/gmond.conf", "chk": "/etc/ganglia/gmond.conf"},
        {"name": "gstat         ", "show": True, "exe": "/usr/bin/gstat -n1", "chk": "/usr/bin/gstat"},
        {"name": "ls-sshd_config", "show": True, "exe": "ls -l /etc/ssh/sshd_config", "chk": "/etc/ssh/sshd_config"},
        {"name": "sshd_config   ", "show": True, "exe": "cat   /etc/ssh/sshd_config", "chk": "/etc/ssh/sshd_config"},
        {"name": "ls-ssh_config ", "show": True, "exe": "ls -l /etc/ssh/ssh_config", "chk": "/etc/ssh/ssh_config"},
        {"name": "ssh_config    ", "show": True, "exe": "cat   /etc/ssh/ssh_config", "chk": "/etc/ssh/ssh_config"},
        {"name": "ls-shostsequiv", "show": True, "exe": "ls -l /etc/ssh/shosts.equiv", "chk": "/etc/ssh/shosts.equiv"},
        {"name": "shostsequiv   ", "show": True, "exe": "cat   /etc/ssh/shosts.equiv", "chk": "/etc/ssh/shosts.equiv"},
        {"name": "ls-knownhosts ", "show": True, "exe": "ls -l /etc/ssh/ssh_known_hosts",
         "chk": "/etc/ssh/ssh_known_hosts"},
        {"name": "ssh_known_host", "show": True, "exe": "cat   /etc/ssh/ssh_known_hosts",
         "chk": "/etc/ssh/ssh_known_hosts"},
        {"name": "ls-hosts.equiv", "show": True, "exe": "ls -l /etc/hosts.equiv", "chk": "/etc/hosts.equiv"},
        {"name": "hosts.equiv   ", "show": True, "exe": "cat   /etc/hosts.equiv", "chk": "/etc/hosts.equiv"},
        {"name": "original-ks   ", "show": True, "exe": "cat   /root/original-ks.cfg", "chk": "/root/original-ks.cfg"},
        {"name": "anaconda-ks   ", "show": True, "exe": "cat   /root/anaconda-ks.cfg", "chk": "/root/anaconda-ks.cfg"},
        {"name": "mypost.log    ", "show": True, "exe": "cat   /root/mypost.log", "chk": "/root/mypost.log"},
        {"name": "nvidia_smi    ", "show": True, "exe": "/usr/bin/nvidia-smi",    "chk": "/usr/bin/nvidia-smi"},
        {"name": "nvidia_smi_q  ", "show": True, "exe": "/usr/bin/nvidia-smi -q", "chk": "/usr/bin/nvidia-smi"},
        {"name": "nvidia_topom  ", "show": True, "exe": "/usr/bin/nvidia-smi topo -m", "chk": "/usr/bin/nvidia-smi"},
        {"name": "nvidia_nvlnk_r", "show": True, "exe": "/usr/bin/nvidia-smi nvlink -R", "chk": "/usr/bin/nvidia-smi"},
        {"name": "nvidia_nvlnk_s", "show": True, "exe": "/usr/bin/nvidia-smi nvlink -s", "chk": "/usr/bin/nvidia-smi"},
        {"name": "nvidia_nvlnk_c", "show": True, "exe": "/usr/bin/nvidia-smi nvlink -c", "chk": "/usr/bin/nvidia-smi"},
        {"name": "perftest_mkl", "show": False, "exe": "( cd /root/system_info/mkl ; LANG=C ./run.sh )", "chk": "/root/system_info/mkl"},
        {"name": "perftest_stream", "show": False, "exe": "( cd /root/system_info/stream ; LANG=C ./run.sh )", "chk": "/root/system_info/stream"},
        {"name": "list-timers   ", "show": True, "exe": "systemctl --no-pager list-timers --all", "chk": "/usr/bin/systemctl"},
        {"name": "kvm-run-xml-files ", "show": True,
         "exe": "ls -1 /run/libvirt/qemu/*.xml 2>/dev/null | xargs -i bash -c 'echo ; echo :::EL7::: kvm_`basename {}`; cat {}'",
         "chk": "/bin/true"},
        {"name": "kvm-xml-files2", "show": True,
         "exe": "ls -1 /etc/libvirt/qemu/*.xml 2>/dev/null | xargs -i bash -c 'echo ; echo :::EL7::: `basename {}`; cat {}'",
         "chk": "/bin/true"},
        {"name": "bootloader", "show": True,
         "exe": "ls -1 /boot/loader/entries/*.conf 2>/dev/null | xargs -i bash -c 'echo ; echo :::EL7::: boot-$(basename {}); cat {}'",
         "chk": "/bin/true"},
        {"name": "mlxlink-ib0", "show": True,
         "exe": "sed -n 's/PCI_SLOT_NAME=//p' /sys/class/net/ib*/device/uevent 2>/dev/null | xargs -t -i bash -c 'echo ; echo :::EL7:::  mlxlink-{}; mlxlink -d {} -m'",
         "chk": "/usr/bin/mlxlink"},
        {"name": "mstlink-ib0", "show": True,
         "exe": "sed -n 's/PCI_SLOT_NAME=//p' /sys/class/net/ib*/device/uevent 2>/dev/null | xargs -t -i bash -c 'echo ; echo :::EL7:::  mstlink-{}; mstlink -d {} -m'",
         "chk": "/usr/bin/mstlink"},
        {"name": "mstconfig-ib0", "show": True,
         "exe": "sed -n 's/PCI_SLOT_NAME=//p' /sys/class/net/ib*/device/uevent 2>/dev/null | xargs -t -i bash -c 'echo ; echo :::EL7:::  mstconfig-{}; mstconfig -d {} q'",
         "chk": "/usr/bin/mstconfig"},
        {"name": "mstflint-ib0", "show": True,
         "exe": "sed -n 's/PCI_SLOT_NAME=//p' /sys/class/net/ib*/device/uevent 2>/dev/null | xargs -t -i bash -c 'echo ; echo :::EL7:::  mstflint-{}; mstflint -d {} q full'",
         "chk": "/usr/bin/mstflint"},
        {"name": "sysfindversion", "show": True, "exe": "/root/bin/sysfind.py -v", "chk": "/bin/true"}
    ])

    return kconf


# ----------------------
#   MAIN
# ----------------------
def main():
    """sysfind.py
    #
    #    System Information Collector Tool (sysfind.py)
    #    Ver 1.00  Copyright (c) 2019,2022 Scalable Systems. Co., Ltd
    #    Ver 1.01  sysfind                                 07.23.2019
    #    Ver 1.02  sysfind single file (kconf)             07.31.2019
    #    Ver 1.03  nfsstat                                 08.26.2019
    #    Ver 1.04  Redirect log file                       10.29.2019
    #              (e.g) "hostname_systeminfo_20191029_144405.txt"
    #    Ver 1.05  nmcli                                   11.07.2019
    #    Ver 1.06  [-q|--quiet] [-n|--dry-run] flags       11.12.2019
    #    Ver 1.07  Add "journalctl  -a  --no-pager"        11.27.2019
    #    Ver 1.08  Add "cgsnapshot cgconfig.conf"          12.03.2019
    #    Ver 1.09  Add "sysfindversion"                    12.04.2019
    #    Ver 1.10  Add "timedatectl"                       12.12.2019
    #    Ver 1.11  Add "vsmpctl --status"                  01.14.2020
    #    Ver 1.12  /sys/devices/system/cpu/vulnerabilities 01.30.2020
    #    Ver 1.13  os.system() -> subprocess.call()        01.31.2020
    #    Ver 1.14  Command path check shutil.which(cmd)    02.27.2020
    #    Ver 1.15  nvidia-smi                              03.02.2020
    #    Ver 1.16  biosdevname -d                          03.03.2020
    #    Ver 1.17  numastat -m                             03.05.2020
    #    Ver 1.18  lsusb -t                                03.25.2020
    #    Ver 1.19  sas3ircu                                08.25.2020
    #    Ver 1.20  vmstat -[dsa]wt                         09.15.2020
    #    Ver 1.21  /etc/sysctl.d files                     03.11.2020
    #    Ver 1.22  lsblk_all                               04.02.2020
    #    Ver 1.23  ls-crash                                04.12.2020
    #    Ver 1.24  abrt-cli list                           10.14.2021
    #    Ver 1.25  rpcinfo [-p|-s]                         12.10.2021
    #    Ver 1.26  netstat -an                             12.13.2021
    #    Ver 1.27  inxi '-y 120' add                       02.09.2022
    #    Ver 1.28  ipmitool user  list 1                   02.28.2022
    #    Ver 1.29  ifstat                                  04.13.2022
    #    Ver 1.30  sfdisk_sda,sdb,sdc,nvme0                04.26.2022
    #    Ver 1.31  findmnt [-l]                            07.25.2022
    #    Ver 1.32  ibv_devinfo [-v]                        08.17.2022
    #    Ver 1.33  systemctl list-timers                   09.02.2022
    #    Ver 1.34  /boot/efi/EFI/redhat/grub.cfg           09.07.2022
    #    Ver 1.35  original-ks.cfg, anaconda-ks.cfg        09.29.2022
    #    Ver 1.36  NetworkManager/system-connections       03.31.2023
    #    Ver 1.37  systemctl list-jobs                     05.23.2023
    #    Ver 1.38  lsinitrd                                06.07.2023
    #    Ver 1.39  xorg.conf                               08.09.2023
    #    Ver 1.40  Perftest mkl/stream                     08.18.2023
    #    Ver 1.41  journalctl list-boots                   12.04.2023
    #    Ver 1.42  Add journalctl --since "1mounth ago"    12.07.2023
    #    Ver 1.43  ubuntu: netplan, ntpq                   01.05.2024
    #    Ver 1.44  "Prof 1.nmconnections" RH9, ethtool -i  01.26.2024
    #    Ver 1.45  yum -v grouplist hidden                 02.09.2024
    #    Ver 1.46  OLD gmetad3.conf gmond3.conf            05.14.2024
    #    Ver 1.47  LC_ALL="en_US.utf-8" subprocess.run()   05.24.2024 
    #    Ver 1.48  /etc/libvirt/qemu/*.xml (False)         06.04.2024 
    #    Ver 1.49  /boot/loader/entries/xxx.conf           06.05.2024 
    #    Ver 1.50  /boot/efi/EFI/rocky/grub.cfg            06.07.2024
    #    Ver 1.51  ADD: netstat -s                         10.07.2024
    #    Ver 1.52  MOD: storcli64 /c0/eALL/sALL show all   10.10.2024
    #    Ver 1.53  ADD: lsmem -a                           10.18.2024
    #    Ver 1.54  ADD: NVIDIA NVLINK                      11.15.2024
    #    Ver 1.55  ADD: arp -aven                          12.03.2024
    #    Ver 1.56  ADD: sfdisk_nvme0n1                     06.18.2025
    #    Ver 1.57  ADD: pbsnodes -aS                       06.19.2025
    #    Ver 1.58  ADD: yum history                        07.22.2025
    #    Ver 1.59  ADD: resolvectl status                  07.30.2025
    #    Ver 1.60  Timeout=60sec, Time summary Finished    08.20.2025
    #    Ver 1.61  ADD: mstlink /sys/class/net/ib* MOD     08.26.2025
    #    Ver 1.62  ADD: mstconfig mstflint                 08.29.2025
    #    Ver 1.63  ADD: systemctl list-units               08.29.2025
    #
    """
    cwd = os.getcwd()
    thisfile = __file__
    basename = os.path.basename(__file__)
    dirname = os.path.dirname(__file__)

    since = ''
    debug, version, full, quiet, dryrun, perftest, since = parser()
    # print ( 'DryRun = ',dryrun )
    if debug: debugprint(['Current Directory : {0}'.format(cwd), 'Script File Name  : {0}'.format(thisfile)])
    if version:
        print(main.__doc__)
        sys.exit(80)

    linevers = main.__doc__.splitlines(True)
    os.system('date; /usr/bin/hostnamectl')
    print( linevers[-3] )
    # sys.exit(80)
    # statlistfile = 'lists.py'
    # kconf = StatlistImport(debug,statlistfile) 
    kconf = StatlistImportin(debug)
    key = 'sysstatlist'
    if len(since) != 0:
        Journalsince(since, key, kconf)

    if perftest:
        SWPerftest(key, kconf)

    if dryrun:
        Dryrun(key, kconf)
        sys.exit(81)
    stat = StatlistExec(debug, full, quiet, key, kconf)

    return 0


if __name__ == "__main__":
    main()
