#!/usr/bin/python3
# -*- coding: utf-8 -*-

#
import sys
import re
import argparse
import textwrap

def parser():
    parser = argparse.ArgumentParser(description='LSHW Output analysis Tool  ')
    parser.add_argument('arg1', help='NEED: lshw file name')  
    parser.add_argument('-v','--version', action='store_true')  

    args = parser.parse_args()
    return args

def print_wrapped(text, width=80, indent='  '):
    lines = textwrap.wrap(text, width=width)
    for i, line in enumerate(lines):
        if i == 0:
            print(line)
        else:
            print(indent + line)

# ------------------------------------------------------
#    System PART 
# Rack Mount Chassis ORION W410R-G6 (OW227317) Ciara Technologies Config1 423082500013
# ------------------------------------------------------
def syspart( tables, linex):
    desc = []
    hostname = None
    host_idx = None
    # ホスト名を探す（英数字のみ、スペースやコロンを含まない行）
    for idx, subil in enumerate(linex):
        s = subil.strip()
        if re.match(r'^[A-Za-z0-9_-]+$', s):  # 英数字と _ - のみ
            hostname = s
            host_idx = idx
            break
    if hostname is None or host_idx is None:
        return  # ホスト名が見つからなければ何もしない

    desc.append(hostname)
    # ホスト名以降の行だけをdescに追加
    for subil in linex[host_idx+1:]:
        if 'configuration:' in subil:
            break
        if 'capabilities' in subil :
            desc.append(subil.replace('capabilities:', '').strip())
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl, '').strip())
    print(' '.join(desc))
    return

# ------------------------------------------------------
#    *-core PART 
# Motherboard Pro WS W790-CA ASUSTeK COMPUTER INC. Rev 1.xx 230419372700058
# ------------------------------------------------------
def corepart( tables, linex):
    desc=[] 
    for subil in linex:
        if '-firmware' in subil:
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    for item in desc: print( item ,end=' ')
    print( '' )

    return

# ------------------------------------------------------
#    *-firmware PART 
# BIOS American Megatrends Inc. 0803 09/21/2023 L1 cache L2 cache L3 cache CPU Intel Corp. 6.143.8
# ------------------------------------------------------
def firmpart(tables, linex):
    desc=[] 
    for subil in linex:
        if '-memory' in subil or 'capabilities:' in subil :
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    for item in desc: print( item ,end=' ')
    print( '\n' )

    return

# ------------------------------------------------------
#    *-volume PART 
#  
# ------------------------------------------------------
def volumepart(tables, linex):
    desc=[]
    for subil in linex:
        if '-volume' in subil:
            disk = re.sub('.*volume:','',subil)
            desc.append(disk)
        if 'configuration:' in subil :
            vconf = re.sub('.*configuration:','',subil)
            desc.append(vconf)
            break
        if 'capabilities' in subil :
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    for item in desc: print( item ,end=' ')
    print( '' )

    return

# ------------------------------------------------------
#    *-nvme PART 
#  NVMe device Micron_7400_MTFDKCB960TDZ Micron Technology Inc [1344] pci@0000:01:00.0 /dev/nvme0 E1MU23BC 2137331D2927 
# ------------------------------------------------------
def nvmepart(tables, linex):
    desc=[]
    for subil in linex:
        if '-nvme' in subil:
            disk = re.sub('.*nvme','',subil)
            desc.append(disk)
        if 'configuration:' in subil:
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    for item in desc: print( item ,end=' ')
    print( '' )

    return

# ------------------------------------------------------
#    *-disk PART 
# 0 ATA Disk SAMSUNG MZ7L3960 scsi@0:0.0.0 /dev/sda S662NT0WB03541 894GiB (960GB)
# 1 ATA Disk SAMSUNG MZ7L3960 scsi@1:0.0.0 /dev/sdb S662NT0WB03555 894GiB (960GB)
# ------------------------------------------------------
def diskpart( tables, linex):
    desc=[]
    for subil in linex:
        if '-disk:' in subil:
            disk = re.sub('.*disk:','',subil)
            desc.append(disk)
        if 'configuration:' in subil:
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    for item in desc: print( item ,end=' ')
    print( '' )

    return

# ------------------------------------------------------
#    *-raid PART 
# ------------------------------------------------------
def raidpart( tables, linex):
    desc=[]
    for subil in linex:
        if 'configuration:' in subil:
            conf = re.sub('.*configuration:','',subil)
            desc.append(conf)
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    for item in desc: print( item ,end=' ')
    print( '' )

    return

# ------------------------------------------------------
#    *-display PART 
# 3D controller GA100 [A100 PCIe 40GB] [10DE:20F1] NVIDIA Corporation [10DE] 0 pci@0000:43:00.0 a1 33MHz
# 3D controller GA100 [A100 PCIe 40GB] [10DE:20F1] NVIDIA Corporation [10DE] 0 pci@0000:6f:00.0 a1 33MHz
# 3D controller GA100 [A100 PCIe 40GB] [10DE:20F1] NVIDIA Corporation [10DE] 0 pci@0000:c7:00.0 a1 33MHz
# ------------------------------------------------------
def disppart( tables, linex):
    desc=[]
    for subil in linex:
        if 'configuration:' in subil:
            desc.append(subil.replace('configuration:','').strip())
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    for item in desc: print( item ,end=' ')
    print( '' )

    return

# ------------------------------------------------------
#    *-bank PART 
# 31 MTC40F2046S1RC48BA1 Micron 1f 40054FA9 DIMM_P1_P1 64GiB 505MHz (2.0ns) DIMM Synchronous Registered (Buffered) 4800 MHz (0.2 ns)
# ------------------------------------------------------
def bankpart(linex):
    dimmflag=True
    desc=[] 
    tot = 0
    for subil in linex:
        if '-bank:' in subil:
            bank = re.sub('.*bank:','',subil)
            desc.append(bank)
        if 'description:' in subil:
            if 'empty' in subil: dimmflag=False
            desc.append(subil.replace('description:','').strip()[0:180])
        if 'product:' in subil:
            if 'NO DIMM' in subil: dimmflag=False
            desc.append(subil.replace('product:','').strip())
        if 'vendor:' in subil:
            desc.append(subil.replace('vendor:','').strip())
        if 'physical id:' in subil:
            desc.append(subil.replace('physical id:','').strip())
        if 'serial:' in subil:
            desc.append(subil.replace('serial:','').strip())
        if 'slot:' in subil:
            desc.append(subil.replace('slot:','').strip())
            if not dimmflag : 
                break
        if 'size:' in subil:
            sz = subil.replace('size:','').strip()
            #tot += int(sz.replace('GiB',''))
            # 単位ごとに換算
            if sz.endswith('GiB'):
                value = float(sz.replace('GiB','').strip())
            elif sz.endswith('MiB'):
                value = float(sz.replace('MiB','').strip()) / 1024
            elif sz.endswith('KiB'):
                value = float(sz.replace('KiB','').strip()) / (1024 * 1024)
            else:
                value = 0  # 未知の単位の場合は0
            tot += value
            desc.append(sz)
        if 'clock:' in subil:
            desc.append(subil.replace('clock:','').strip())
            break

    desc.append(desc[1])
    del (desc[1])
    for item in desc: print( item ,end=' ')
    print( '' )

    return tot

# ------------------------------------------------------
#    *-cpu: PART 
# 0 CPU Intel(R) Xeon(R) Gold 6448H Intel Corp. cpu@0 6.143.8 CPU0 3995MHz 4100MHz 100MHz
# ------------------------------------------------------
def cpupart( tables, linex):
    desc = []
    for subil in linex:
        if 'configuration:' in subil:
            desc.append(subil.replace('configuration:', '').strip()[0:120])
            break
        if '-cpu:' in subil:
            cpu = re.sub('.*cpu:', '', subil)
            desc.append(cpu)
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl, '').strip())

    # desc全体を1つの文字列に連結し、100文字ごとに折り返し（インデント4文字）
    summary = ' '.join(desc)
    print_wrapped(summary, width=100, indent='    ')
    # print('End of CPU')
    return

# ------------------------------------------------------
#    *-network: PART 
# Wireless interface Cannon Lake PCH CNVi WiFi Intel Corporation 14.3 pci@0000:00:14.3 wlo1 10 f8:e4:e3:a5:95:b0 33MHz
# Ethernet interface Ethernet Connection (7) I219-V Intel Corporation 1f.6 pci@0000:00:1f.6 eno2 10 d4:5d:64:b1:44:b1 1Gbit/s 1Gbit/s 33MHz
# Ethernet interface Ethernet Controller X550 Intel Corporation 0 pci@0000:3b:00.0 ens21f0 01 a0:36:9f:1f:ec:b4 10Gbit/s 10Gbit/s 33MHz
# ------------------------------------------------------
def netpart(tables, linex):
    desc=[]
    for subil in linex:
        if 'configuration:' in subil:
            desc.append(subil.replace('configuration:','').strip()[0:180])
            break
        for tbl in tables:
            if tbl in subil:
                desc.append(subil.replace(tbl,'').strip())

    # desc全体を1つの文字列に連結し、100文字ごとに折り返し（インデント4文字）
    summary = ' '.join(desc)
    print_wrapped(summary, width=100, indent='    ')
    # print( '' )

    return

# ------------------------------------------------------
#    MAIN program 
# ------------------------------------------------------
def split_sections(lines):
    sections = []
    current = []
    for line in lines:
        if line.strip().startswith('*-') and current:
            sections.append(current)
            current = []
        current.append(line)
    if current:
        sections.append(current)
    return sections

def main():
    """neobank.py
    #
    #    lshw -> summary output Tool (Python)
    #    Ver 1.00  First version               04/12/2024
    #    Ver 1.01  New: tables[]               04/15/2024
    #    Ver 1.02  syspart() Hostaname         04/16/2024
    #              '-display' GPU              04/16/2024
    #    Ver 1.03  BUG: '-core' pattern match  04/16/2024
    #    Ver 1.04  RAID driver megaraid        07/08/2024
    #    Ver 1.05  -volume:X added             09/09/2024
    #    Ver 1.06  table,il.strip().startswith 08/08/2025
    #    Ver 1.07  セクションごとに分割        08/08/2025
    #
    """
    args = parser()
    if args.version :
        print(main.__doc__)
        sys.exit(80)
        quit()

    lshwfile = args.arg1
    tables = list(dict.fromkeys([
        'bus info:', 'capacity:', 'clock:', 'configuration:', 'date:', 'description:',
        'logical name:', 'physical id:', 'product:', 'serial:', 'size:', 'slot:',
        'vendor:', 'version:'
    ]))

    with open(lshwfile, "r") as f:
        lines = f.read().splitlines()

    dimtot = 0

    # セクションごとに分割
    sections = split_sections(lines)

    for idx, section in enumerate(sections):
        header = section[0].strip()
        # 最初のセクションが '*-' で始まらない場合は syspart() で処理
        if idx == 0 and not header.startswith('*-'):
            syspart(tables, section)
            continue
        if header.startswith('*-core'):
            corepart(tables, section)
        elif header.startswith('*-firmware'):
            firmpart(tables, section)
        elif header.startswith('*-volume'):
            volumepart(tables, section)
        elif header.startswith('*-nvme'):
            nvmepart(tables, section)
        elif header.startswith('*-raid'):
            raidpart(tables, section)
        elif header.startswith('*-storage'):
            raidpart(tables, section)
        elif header.startswith('*-disk'):
            diskpart(tables, section)
        elif header.startswith('*-display'):
            disppart(tables, section)
        elif header.startswith('*-cpu'):
            cpupart(tables, section)
        elif header.startswith('*-network'):
            netpart(tables, section)
        elif header.startswith('*-bank'):
            tot = bankpart(section)
            dimtot += tot

    print(f'Total DIMM = {dimtot} GiB')
    return True

if __name__ == '__main__':
    main()

