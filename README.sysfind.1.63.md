
### newsysfind.py    Ver 1.63  ADD: systemctl list-units               08.29.2025

## TIMEOUT = 90 sec

```bash
<     TIMEOUT_SEC = 60
---
>     TIMEOUT_SEC = 90
```

## Limit time summary output over 0.01 seconds.

```bash
>         if sec > 0.01 :
>             summary_lines.append(f"{idx:03d}: {cmd[:50]:50s}  : {sec:.4f} sec")
```

## ADD: systemctl --no-pager list-unit-files 

```bash
>         {"name": "list-unit-file", "show": True, "exe": "/usr/bin/systemctl --no-pager list-unit-files", "chk": "/bin/true"},

```

## Redirect standard error output to /dev/null to suppress error messages.

```bash
sed -n 's/PCI_SLOT_NAME=//p' /sys/class/net/ib*/device/uevent 2>/dev/null
```
