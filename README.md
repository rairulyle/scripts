# scripts

A personal collection of scripts for solving everyday problems: deduplication, storage cleanup, automation, and more.

## Layout

Scripts are organized by platform, then by topic:

```
windows/
  zzz/
    setup-dual-launcher/
```

Each script lives in its own folder with a `README.md` describing what it does and a sample run.

## Usage

Open a script's folder and read its `README.md` for prerequisites and a sample run. PowerShell scripts typically run with:

```powershell
powershell -ExecutionPolicy Bypass -File ".\script-name.ps1"
```

Some scripts require an elevated (Administrator) prompt — check the `#Requires` header at the top of the file.

## License

Personal use. No warranty — read each script before running it.
