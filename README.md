# sysfind
Sysfind collects many system data from Linux server

# Sysfind require
Python 3.x
system_info (for performance test only)

# Sysfind help
```bash
usage: 
  Usage: /work/work_sudo/SYSFIND/GIT/sysfind/./sysfind.py [-d|--debug] [-v|--version] [-f|--full] [-q|--quiet] [-n|--dry-run] [-p|--perftest] [-h|--help]

options:
  -h, --help            show this help message and exit
  -d, --debug           Show debug information about each commanline
  -v, --version         Report version and exit
  -f, --full            Report EVERY items regardless of show=False Flag
  -q, --quiet           Quiet mode: do not show output in stdout
  -n, --dry-run         Dry Run: Just show commands list
  -p, --perftest        Perf Test: Run Perftest - /root/system_info/{mkl,stream}
  -s SINCE, --since SINCE
                        Journalctl --since "1mounths ago" : or --since $(date -I --date '10days
                        ago' )
```

# Version history
```bash
sysfind.py
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
```

