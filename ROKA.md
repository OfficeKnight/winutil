# WinUtil RoKa Edition

A fork of [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil), which is MIT licensed (see `LICENSE`). Everything upstream ships stays in place. This file describes what the fork adds and how it is kept apart from upstream so that upstream updates merge cleanly.

## Where the additions live

- `functions/roka/`: functions that only exist in this fork. `Compile.ps1` picks them up because it reads `functions/` recursively.
- `config/roka*.json`: configuration that only exists in this fork. Each file is embedded as `$sync.configs.<file name>`.
- `pester/roka-*.Tests.ps1`: tests for the additions.
- `.github/workflows/roka-*.yaml`: workflows for the fork.

Upstream files are changed only where an addition has to be called from. Each of those places is a few lines long, starts with a `RoKa Edition` comment, and does nothing when its config is absent, so upstream's own tests keep running unchanged.

## Danger list

`config/rokadanger.json` names the entries that can break Windows or cannot be undone, each with the reason shown to the user. The key is a tweak key from `config/tweaks.json` or the name of a control in `xaml/inputXML.xaml`.

An entry on the list:

- is drawn in red with a red outline, and its tooltip starts with the reason (`Set-WinUtilDangerHighlight`, called from `Initialize-WinUtilTabContent`)
- is never selected by a preset, an imported config or a headless `-Preset` / `-Config` run; it is left out and the log says so (`Update-WinUtilSelections`)
- can still be ticked by hand, and then needs its own confirmation when tweaks are applied: Yes applies everything, No leaves the danger-listed entries out, Cancel applies nothing (`Confirm-WinUtilDangerSelection`, called from `Invoke-WPFtweaksbutton`). Without a window the answer is always No.

The `Disable Updates` button on the Updates tab is marked the same way and keeps the confirmation upstream already gives it.

To add an entry, add its key and reason to `config/rokadanger.json`. `pester/roka-danger.Tests.ps1` fails when a key matches neither a tweak nor a named control.

## Staying in step with upstream

`.github/workflows/roka-upstream-sync.yaml` opens a pull request on the first day of every month with everything new on upstream `main`. Nothing is merged automatically. Test the pull request in the VM, then merge it with "Create a merge commit" rather than a squash, so the next run can tell what has already been taken over.

The workflow needs "Allow GitHub Actions to create and approve pull requests" under Settings > Actions > General, and GitHub Actions have to be enabled on the fork.

## Building

```powershell
.\Compile.ps1
```

This writes `winutil.ps1`, which is the file that goes on the USB stick. It is build output and is never committed.
