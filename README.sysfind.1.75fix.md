# sysfind.py v1.75.fix

## Ver 1.75  ADD: rasdaemon ras-mc-ctl               06.24.2026
- ras-mc-ctl --summary, ras-mc-ctl --errors を追加 06.24.2026


```python
        {"name": "rasmcctl-summary", "show": True, "exe": "ras-mc-ctl --summary", "chk": "/var/lib/rasdaemon/ras-mc_event.db"},
        {"name": "rasmcctl-errors" , "show": True, "exe": "ras-mc-ctl --errors", "chk": "/var/lib/rasdaemon/ras-mc_event.db"},

```
