#!/usr/bin/env python3
import os
import re
import sys

def parse_dmidecode(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File not found -> {file_path}")
        sys.exit(1)

    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()

    # 「Handle 0x」で各セクションに分割
    blocks = re.split(r'\n(?=Handle 0x)', content)
    
    summary_data = {
        "bios": {},
        "system": {},
        "baseboard": {},
        "cpus": [],
        "memory": [],
        "psu": []
    }
    
    for block in blocks:
        lines = block.strip().split('\n')
        if not lines:
            continue
            
        # 鍵と値をパースするための辞書
        dev_info = {}
        for line in lines:
            if ':' in line:
                key, val = line.split(':', 1)
                dev_info[key.strip()] = val.strip()

        # 正規表現でDMI Typeを確実に判定
        is_type0  = re.search(r'DMI type 0\b', block)
        is_type1  = re.search(r'DMI type 1\b', block)
        is_type2  = re.search(r'DMI type 2\b', block)
        is_type4  = re.search(r'DMI type 4\b', block)
        is_type17 = re.search(r'DMI type 17\b', block)
        is_type39 = re.search(r'DMI type 39\b', block)

        # 0. BIOS Information (Type 0)
        if is_type0:
            summary_data["bios"] = {
                "Vendor": dev_info.get("Vendor", "N/A"),
                "Version": dev_info.get("Version", "N/A"),
                "Release Date": dev_info.get("Release Date", "N/A")
            }

        # 1. System Information (Type 1)
        elif is_type1:
            summary_data["system"] = {
                "Manufacturer": dev_info.get("Manufacturer", "N/A"),
                "Product Name": dev_info.get("Product Name", "N/A"),
                "Serial Number": dev_info.get("Serial Number", "N/A")
            }

        # 2. Base Board Information (Type 2)
        elif is_type2:
            summary_data["baseboard"] = {
                "Manufacturer": dev_info.get("Manufacturer", "N/A"),
                "Product Name": dev_info.get("Product Name", "N/A"),
                "Serial Number": dev_info.get("Serial Number", "N/A")
            }

        # 3. Processor Information (Type 4)
        elif is_type4:
            summary_data["cpus"].append({
                "Socket": dev_info.get("Socket Designation", "N/A"),
                "Model": dev_info.get("Version", "N/A"),
                "Cores": dev_info.get("Core Count", "N/A"),
                "Threads": dev_info.get("Thread Count", "N/A"),
                "Speed": dev_info.get("Current Speed", "N/A"),
                "Serial": dev_info.get("Serial Number", "N/A")
            })

        # 4. Memory Device (Type 17)
        elif is_type17:
            size = dev_info.get("Size", "")
            if size and "No Module Installed" not in size and "Unknown" not in size:
                summary_data["memory"].append({
                    "Locator": dev_info.get("Locator", "N/A"),
                    "Manufacturer": dev_info.get("Manufacturer", "N/A"),
                    "Size": size,
                    "Type": dev_info.get("Type", "N/A"),
                    "Speed": dev_info.get("Configured Memory Speed", dev_info.get("Speed", "N/A")),
                    "Serial": dev_info.get("Serial Number", "N/A"),
                    "PartNo": dev_info.get("Part Number", "N/A")
                })

        # 5. System Power Supply (Type 39)
        elif is_type39:
            summary_data["psu"].append({
                "Location": dev_info.get("Location", "N/A"),
                "Manufacturer": dev_info.get("Manufacturer", "N/A"),
                "Model": dev_info.get("Name", dev_info.get("Model Part Number", "N/A")),
                "Serial": dev_info.get("Serial Number", "N/A")
            })
            
    return summary_data

def parse_memory_size_gb(size_str):
    gb_match = re.search(r'(\d+)\s*GB', size_str, re.IGNORECASE)
    if gb_match:
        return int(gb_match.group(1))
    mb_match = re.search(r'(\d+)\s*MB', size_str, re.IGNORECASE)
    if mb_match:
        return int(mb_match.group(1)) // 1024
    return 0

def generate_report(data, file_path):
    output = []
    output.append("=" * 95)
    output.append(f" HARDWARE ASSET REPORT (Source: {file_path})")
    output.append("=" * 95)
    
    # System & Motherboard & BIOS Section
    sys_info = data.get("system", {})
    bb_info = data.get("baseboard", {})
    bios_info = data.get("bios", {})
    
    output.append("\n[1. SYSTEM & BOARD INFORMATION]")
    output.append(f"  * System Manufacturer : {sys_info.get('Manufacturer', 'N/A')}")
    output.append(f"  * System Product Name : {sys_info.get('Product Name', 'N/A')}")
    output.append(f"  * System Serial Number: {sys_info.get('Serial Number', 'N/A')}")
    output.append(f"  * Baseboard Model     : {bb_info.get('Product Name', 'N/A')}")
    output.append(f"  * Baseboard Serial    : {bb_info.get('Serial Number', 'N/A')}")
    output.append(f"  * BIOS Vendor/Version : {bios_info.get('Vendor', 'N/A')} / {bios_info.get('Version', 'N/A')} (Date: {bios_info.get('Release Date', 'N/A')})")
    
    # CPU Section
    cpus = data.get("cpus", [])
    output.append("\n[2. PROCESSOR INFORMATION]")
    if not cpus:
        output.append("  * No processor information found")
    for idx, cpu_info in enumerate(cpus, start=1):
        if len(cpus) > 1:
            output.append(f"  --- CPU #{idx} ---")
        output.append(f"  * Model        : {cpu_info.get('Model', 'N/A')}")
        output.append(f"  * Socket       : {cpu_info.get('Socket', 'N/A')}")
        output.append(f"  * Cores/Threads: {cpu_info.get('Cores', 'N/A')} Cores / {cpu_info.get('Threads', 'N/A')} Threads")
        output.append(f"  * Current Speed: {cpu_info.get('Speed', 'N/A')}")
        output.append(f"  * CPU Serial   : {cpu_info.get('Serial', 'N/A')}")

    # Memory Section
    output.append("\n[3. MEMORY DEVICE SUMMARY]")
    mem_fmt = "  {:<14} {:<14} {:<8} {:<6} {:<12} {:<15} {:<20}"
    output.append(mem_fmt.format("Locator", "Manufacturer", "Size", "Type", "Speed", "Serial Number", "Part Number"))
    output.append("  " + "-" * 91)
    total_size_gb = 0
    for mem in data.get("memory", []):
        output.append(mem_fmt.format(mem["Locator"], mem["Manufacturer"], mem["Size"], mem["Type"], mem["Speed"], mem["Serial"], mem["PartNo"]))
        total_size_gb += parse_memory_size_gb(mem["Size"])
    output.append("  " + "-" * 91)
    output.append(f"  * Total Active DIMMs   : {len(data.get('memory', []))} slots")
    output.append(f"  * Total Memory Capacity: {total_size_gb} GB")

    # PSU Section
    output.append("\n[4. SYSTEM POWER SUPPLY]")
    psu_fmt = "  {:<10} {:<14} {:<18} {:<15}"
    output.append(psu_fmt.format("Location", "Manufacturer", "Model/Name", "Serial Number"))
    output.append("  " + "-" * 61)
    for psu in data.get("psu", []):
        output.append(psu_fmt.format(psu["Location"], psu["Manufacturer"], psu["Model"], psu["Serial"]))
    output.append("  " + "-" * 61)
    output.append("\n" + "=" * 95)
    
    return "\n".join(output)

if __name__ == "__main__":
    target_file = "dmidecode.txt"
    if len(sys.argv) > 1:
        target_file = sys.argv[1]
        
    # パースとレポート生成
    parsed_data = parse_dmidecode(target_file)
    report_text = generate_report(parsed_data, target_file)
    
    # 1. 画面（標準出力）に表示
    print(report_text)
    
    # 2. テキストファイルに保存
    output_filename = "hardware_summary.txt"
    with open(output_filename, 'w', encoding='utf-8') as f:
        f.write(report_text)
        
    print(f"\n[Success] Summary report saved to '{output_filename}'")

