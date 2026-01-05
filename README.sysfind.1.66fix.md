# sysfind.py v1.66.fix

## Changes from v1.66
- klist コマンドが無い場合のエラー対応(except FileNotFoundError)追加


```python
71a72,77
> # def has_valid_tgt():
> #     return subprocess.run(
> #         ["klist", "-s"],
> #         stdout=subprocess.DEVNULL,
> #         stderr=subprocess.DEVNULL,
> #     ).returncode == 0
73,78c79,89
<     return subprocess.run(
<         ["klist", "-s"],
<         stdout=subprocess.DEVNULL,
<         stderr=subprocess.DEVNULL,
<     ).returncode == 0
< 
---
>     try:
>         # klist を実行し、正常終了(0)なら True
>         return subprocess.run(
>             ["klist", "-s"],
>             stdout=subprocess.DEVNULL,
>             stderr=subprocess.DEVNULL,
>         ).returncode == 0
>     except FileNotFoundError:
>         # klist コマンド自体が存在しない場合は、有効な資格情報はないと判断して False
>         logging.debug("klist command not found in the system")
>         return False
```
