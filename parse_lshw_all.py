#!/usr/bin/env python3
import os
import re
import sys


class LshwNode:
    def __init__(self, node_id, indent):
        self.id = node_id
        self.indent = indent
        self.props = {}
        self.children = []


def parse_configuration(config_str):
    result = {}
    for part in config_str.split():
        if "=" in part:
            key, val = part.split("=", 1)
            result[key] = val
    return result


def get_firmware(config_str):
    match = re.search(r"firmware=(.+?)(?:\s+[a-z][\w.]*=|$)", config_str)
    if match:
        return match.group(1).strip().rstrip(",")
    return "N/A"


def format_mac(mac):
    if mac == "N/A":
        return mac
    return mac[:18]


def add_prop(node, key, value):
    if key in node.props:
        existing = node.props[key]
        if isinstance(existing, list):
            if value not in existing:
                existing.append(value)
        elif existing != value:
            node.props[key] = [existing, value]
    else:
        node.props[key] = value


def get_prop(node, key, default="N/A"):
    value = node.props.get(key, default)
    if isinstance(value, list):
        return value[-1]
    return value if value else default


def get_logical_names(node):
    value = node.props.get("logical name", [])
    if isinstance(value, list):
        return value
    if value:
        return [value]
    return []


def parse_lshw_tree(content):
    root = None
    stack = []
    skip_prefixes = (":::EL7:::", "    CMD:", "#")

    for line in content.splitlines():
        if not line.strip():
            continue
        if any(line.startswith(prefix) for prefix in skip_prefixes):
            continue

        node_match = re.match(r"^(\s*)\*-(.+)$", line)
        if node_match:
            indent = len(node_match.group(1))
            node_id = node_match.group(2).strip()
            node = LshwNode(node_id, indent)

            while stack and stack[-1].indent >= indent:
                stack.pop()

            if stack:
                stack[-1].children.append(node)
            elif root is None:
                root = LshwNode("system", 0)
                root.children.append(node)
                stack = [root]

            stack.append(node)
            continue

        prop_match = re.match(r"^(\s+)([^:]+):\s*(.*)$", line)
        if not prop_match:
            if root is None and not line.startswith(" "):
                root = LshwNode(line.strip(), 0)
                stack = [root]
            continue

        indent = len(prop_match.group(1))
        key = prop_match.group(2).strip()
        value = prop_match.group(3).strip()

        if root is None:
            root = LshwNode("system", 0)
            stack = [root]

        while stack and stack[-1].indent >= indent:
            stack.pop()
        if not stack:
            stack = [root]

        add_prop(stack[-1], key, value)

    return root


def walk_nodes(node, callback):
    callback(node)
    for child in node.children:
        walk_nodes(child, callback)


def find_nodes(root, id_pattern):
    results = []

    def visit(node):
        if re.search(id_pattern, node.id):
            results.append(node)

    walk_nodes(root, visit)
    return results


def derive_partition_device(parent_device, volume_node):
    names = get_logical_names(volume_node)
    device = next((name for name in names if name.startswith("/dev/")), None)
    if device:
        return device

    part_id = get_prop(volume_node, "physical id", "")
    if not parent_device.startswith("/dev/") or not part_id.isdigit():
        return "N/A"

    if re.match(r"/dev/nvme\d+n\d+$", parent_device):
        return f"{parent_device}p{part_id}"
    return f"{parent_device}{part_id}"


def extract_partition(volume_node, parent_device="N/A"):
    device = derive_partition_device(parent_device, volume_node)
    names = get_logical_names(volume_node)
    mount = next((name for name in names if not name.startswith("/dev/")), "N/A")

    config = parse_configuration(get_prop(volume_node, "configuration", ""))
    if mount == "N/A":
        mount = config.get("lastmountpoint", "N/A")

    filesystem = config.get("mount.fstype", config.get("filesystem", "N/A"))
    if filesystem == "N/A":
        config_name = config.get("name", "")
        if config_name in ("xfs", "ext4", "ext3", "ext2", "fat", "vfat", "btrfs", "ntfs"):
            filesystem = config_name
    if filesystem == "N/A":
        version = get_prop(volume_node, "version", "")
        if version in ("FAT16", "FAT32"):
            filesystem = "fat"
        elif "swap" in get_prop(volume_node, "description", "").lower():
            filesystem = "swap"
        elif "ext4" in get_prop(volume_node, "description", "").lower():
            filesystem = "ext4"

    size = get_prop(volume_node, "size", "N/A")
    if size == "N/A":
        size = get_prop(volume_node, "capacity", "N/A")

    part_name = config.get("name", "N/A")
    if part_name in ("xfs", "ext4", "ext3", "ext2", "fat", "vfat", "btrfs", "ntfs", "swap"):
        part_name = mount if mount != "N/A" else get_prop(volume_node, "description", "N/A")

    return {
        "Device": device,
        "Size": size,
        "Filesystem": filesystem,
        "Mount": mount,
        "Name": part_name,
        "Description": get_prop(volume_node, "description", "N/A"),
    }


def is_network_interface_node(node):
    names = get_logical_names(node)
    iface = next((name for name in names if not name.startswith("/dev/")), None)
    if not iface:
        return False

    desc = get_prop(node, "description", "").lower()
    caps = get_prop(node, "capabilities", "").lower()
    driver = parse_configuration(get_prop(node, "configuration", "")).get("driver", "").lower()

    if "ethernet" in desc or "ethernet" in caps:
        return True
    if iface.startswith("ib") or "infiniband" in caps or "infiniband" in desc:
        return True
    if driver.startswith("ib_") or "ipoib" in driver:
        return True
    return False


def extract_storage(root):
    storage = []

    for disk_node in find_nodes(root, r"^disk(:\d+)?$"):
        description = get_prop(disk_node, "description", "")
        if "SCSI" in description:
            disk_type = "SCSI"
        elif "ATA" in description:
            disk_type = "ATA"
        else:
            disk_type = "Disk"

        disk_device = get_prop(disk_node, "logical name", "N/A")
        disk = {
            "Type": disk_type,
            "Device": disk_device,
            "Vendor": get_prop(disk_node, "vendor", "N/A"),
            "Product": get_prop(disk_node, "product", "N/A"),
            "Size": get_prop(disk_node, "size", "N/A"),
            "Serial": get_prop(disk_node, "serial", "N/A"),
            "Partitions": [],
        }
        for child in disk_node.children:
            if re.match(r"^volume", child.id):
                disk["Partitions"].append(extract_partition(child, disk_device))
        storage.append(disk)

    for nvme_node in find_nodes(root, r"^nvme$"):
        for ns_node in nvme_node.children:
            if not re.match(r"^namespace", ns_node.id):
                continue
            device = get_prop(ns_node, "logical name", "")
            if not device.startswith("/dev/nvme") or device.startswith("/dev/ng"):
                continue

            disk = {
                "Type": "NVMe",
                "Device": device,
                "Vendor": get_prop(nvme_node, "vendor", "N/A"),
                "Product": get_prop(nvme_node, "product", "N/A"),
                "Size": get_prop(ns_node, "size", "N/A"),
                "Serial": get_prop(nvme_node, "serial", "N/A"),
                "Partitions": [],
            }
            for child in ns_node.children:
                if re.match(r"^volume", child.id):
                    disk["Partitions"].append(extract_partition(child, device))
            storage.append(disk)

    return storage


def parse_lshw(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File not found -> {file_path}")
        sys.exit(1)

    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    root = parse_lshw_tree(content)
    if root is None:
        print(f"Error: Failed to parse lshw tree -> {file_path}")
        sys.exit(1)

    core_nodes = find_nodes(root, r"^core$")
    core = core_nodes[0] if core_nodes else None

    summary = {
        "hostname": root.id if root.id != "system" else get_prop(root, "product", "N/A"),
        "system": {
            "Description": get_prop(root, "description", "N/A"),
            "Product": get_prop(root, "product", "N/A"),
            "Vendor": get_prop(root, "vendor", "N/A"),
            "Serial": get_prop(root, "serial", "N/A"),
        },
        "baseboard": {},
        "bios": {},
        "cpus": [],
        "memory": [],
        "storage": [],
        "network": [],
        "display": [],
    }

    if core:
        summary["baseboard"] = {
            "Product": get_prop(core, "product", "N/A"),
            "Vendor": get_prop(core, "vendor", "N/A"),
            "Serial": get_prop(core, "serial", "N/A"),
        }

        firmware_nodes = [child for child in core.children if child.id.startswith("firmware")]
        if firmware_nodes:
            bios = firmware_nodes[0]
            summary["bios"] = {
                "Vendor": get_prop(bios, "vendor", "N/A"),
                "Version": get_prop(bios, "version", "N/A"),
                "Date": get_prop(bios, "date", "N/A"),
            }

    for cpu_node in find_nodes(root, r"^cpu:\d+"):
        config = parse_configuration(get_prop(cpu_node, "configuration", ""))
        summary["cpus"].append({
            "Model": get_prop(cpu_node, "product", "N/A"),
            "Socket": get_prop(cpu_node, "slot", "N/A"),
            "Cores": config.get("cores", "N/A"),
            "Threads": config.get("threads", "N/A"),
            "Speed": get_prop(cpu_node, "size", "N/A"),
            "Serial": get_prop(cpu_node, "serial", "N/A"),
        })

    for bank_node in find_nodes(root, r"^bank:\d+"):
        description = get_prop(bank_node, "description", "")
        if "[empty]" in description or get_prop(bank_node, "product", "") == "NO DIMM":
            continue

        mem_type = "N/A"
        type_match = re.search(r"DIMM\s+(\S+)", description)
        if type_match:
            mem_type = type_match.group(1)

        summary["memory"].append({
            "Locator": get_prop(bank_node, "slot", "N/A"),
            "Manufacturer": get_prop(bank_node, "vendor", "N/A"),
            "Size": get_prop(bank_node, "size", "N/A"),
            "Type": mem_type,
            "Speed": get_prop(bank_node, "clock", "N/A"),
            "Serial": get_prop(bank_node, "serial", "N/A"),
            "PartNo": get_prop(bank_node, "product", "N/A"),
        })

    summary["storage"] = extract_storage(root)

    for net_node in find_nodes(root, r"^network(:\d+)?$"):
        if not is_network_interface_node(net_node):
            continue
        names = get_logical_names(net_node)
        iface = next((name for name in names if not name.startswith("/dev/")), "N/A")
        config_str = get_prop(net_node, "configuration", "")
        config = parse_configuration(config_str)
        summary["network"].append({
            "Interface": iface,
            "Product": get_prop(net_node, "product", "N/A"),
            "Firmware": get_firmware(config_str),
            "MAC": format_mac(get_prop(net_node, "serial", "N/A")),
            "Speed": get_prop(net_node, "size", "N/A"),
            "IP": config.get("ip", "N/A"),
        })

    for display_node in find_nodes(root, r"^display$"):
        summary["display"].append({
            "Product": get_prop(display_node, "product", "N/A"),
            "Vendor": get_prop(display_node, "vendor", "N/A"),
            "Driver": parse_configuration(get_prop(display_node, "configuration", "")).get("driver", "N/A"),
        })

    return summary


def parse_memory_size_gib(size_str):
    gib_match = re.search(r"(\d+(?:\.\d+)?)\s*GiB", size_str, re.IGNORECASE)
    if gib_match:
        return float(gib_match.group(1))
    gb_match = re.search(r"(\d+(?:\.\d+)?)\s*GB", size_str, re.IGNORECASE)
    if gb_match:
        return float(gb_match.group(1))
    mb_match = re.search(r"(\d+(?:\.\d+)?)\s*MiB", size_str, re.IGNORECASE)
    if mb_match:
        return float(mb_match.group(1)) / 1024
    return 0


def generate_report(data, file_path):
    output = []
    output.append("=" * 95)
    output.append(f" HARDWARE ASSET REPORT (Source: {file_path})")
    output.append("=" * 95)

    sys_info = data.get("system", {})
    bb_info = data.get("baseboard", {})
    bios_info = data.get("bios", {})

    output.append(f"\nHost: {data.get('hostname', 'N/A')}")
    output.append("\n[1. SYSTEM & BOARD INFORMATION]")
    output.append(f"  * System Description  : {sys_info.get('Description', 'N/A')}")
    output.append(f"  * System Product Name   : {sys_info.get('Product', 'N/A')}")
    output.append(f"  * System Vendor         : {sys_info.get('Vendor', 'N/A')}")
    output.append(f"  * System Serial Number  : {sys_info.get('Serial', 'N/A')}")
    output.append(f"  * Baseboard Model       : {bb_info.get('Product', 'N/A')}")
    output.append(f"  * Baseboard Serial      : {bb_info.get('Serial', 'N/A')}")
    output.append(
        f"  * BIOS Vendor/Version   : {bios_info.get('Vendor', 'N/A')} / "
        f"{bios_info.get('Version', 'N/A')} (Date: {bios_info.get('Date', 'N/A')})"
    )

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

    output.append("\n[3. MEMORY DEVICE SUMMARY]")
    mem_fmt = "  {:<14} {:<14} {:<8} {:<6} {:<12} {:<15} {:<20}"
    output.append(mem_fmt.format("Locator", "Manufacturer", "Size", "Type", "Speed", "Serial Number", "Part Number"))
    output.append("  " + "-" * 91)
    total_size_gib = 0
    for mem in data.get("memory", []):
        output.append(mem_fmt.format(
            mem["Locator"], mem["Manufacturer"], mem["Size"], mem["Type"],
            mem["Speed"], mem["Serial"], mem["PartNo"]
        ))
        total_size_gib += parse_memory_size_gib(mem["Size"])
    output.append("  " + "-" * 91)
    output.append(f"  * Total Active DIMMs   : {len(data.get('memory', []))} slots")
    output.append(f"  * Total Memory Capacity: {total_size_gib:.0f} GiB")

    output.append("\n[4. STORAGE SUMMARY]")
    storage = data.get("storage", [])
    if not storage:
        output.append("  * No storage devices found")
    for disk in storage:
        output.append(f"\n  --- {disk['Type']} Disk: {disk['Device']} ---")
        output.append(f"  * Vendor/Product : {disk['Vendor']} / {disk['Product']}")
        output.append(f"  * Size           : {disk['Size']}")
        output.append(f"  * Serial         : {disk['Serial']}")
        if disk["Partitions"]:
            part_fmt = "    {:<16} {:<12} {:<10} {:<15} {}"
            output.append("  * Partitions:")
            output.append(part_fmt.format("Device", "Size", "FS", "Mount", "Name/Description"))
            output.append("    " + "-" * 85)
            for part in disk["Partitions"]:
                output.append(part_fmt.format(
                    part["Device"], part["Size"], part["Filesystem"],
                    part["Mount"], part["Name"]
                ))
        else:
            output.append("  * Partitions     : (none listed)")

    output.append("\n[5. NETWORK INTERFACES]")
    net_fmt = "  {:<10} {:<30} {:<24} {:<18} {:<12} {}"
    output.append(net_fmt.format("Interface", "Product", "Firmware", "MAC", "Speed", "IP"))
    output.append("  " + "-" * 110)
    for net in data.get("network", []):
        output.append(net_fmt.format(
            net["Interface"], net["Product"], net["Firmware"],
            net["MAC"], net["Speed"], net["IP"]
        ))

    output.append("\n[6. DISPLAY ADAPTERS]")
    if not data.get("display"):
        output.append("  * No display adapters found")
    for display in data.get("display", []):
        output.append(f"  * {display['Vendor']} / {display['Product']} (driver: {display['Driver']})")

    output.append("\n" + "=" * 95)
    return "\n".join(output)


if __name__ == "__main__":
    target_file = "lshw.txt"
    if len(sys.argv) > 1:
        target_file = sys.argv[1]

    parsed_data = parse_lshw(target_file)
    report_text = generate_report(parsed_data, target_file)

    print(report_text)

    output_filename = "hardware_summary_lshw.txt"
    with open(output_filename, "w", encoding="utf-8") as f:
        f.write(report_text)

    print(f"\n[Success] Summary report saved to '{output_filename}'")
