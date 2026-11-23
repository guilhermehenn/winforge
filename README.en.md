<p align="center">
  <img src="assets/WinForge.svg" width="96" height="96" alt="WinForge icon: a white anvil with an orange face">
</p>

# WinForge

[![Latest version](https://img.shields.io/github/v/release/guilhermehenn/winforge?label=version)](https://github.com/guilhermehenn/winforge/releases/latest)
[![GPLv3 license](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)
[![Windows 10 and 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4)](#requirements)
[![Windows PowerShell 5.1](https://img.shields.io/badge/PowerShell-5.1-5391FE)](#requirements)

[Português](README.md) · **English** · [Español](README.es.md)

Take care of your Windows PC in one place: WinForge cleans, repairs, updates and warns you before trouble, in a simple window or, if you prefer, a terminal menu. It asks before anything that matters and keeps track of how things were, so you can go back.

[Website](https://usewinforge.com.br/en/) · [**Download WinForge**](https://github.com/guilhermehenn/winforge/releases/latest/download/WinForge.zip) · [All versions](https://github.com/guilhermehenn/winforge/releases) · [What changed (in Portuguese)](CHANGELOG.md)

## Why WinForge

- **Everything in one place:** cleanup, Windows repair, updates, network, security, programs and tweaks, in four groups: Care, Fix, Protect and Configure.
- **No scares:** anything that deletes or goes deep into the system asks first. Each tweak keeps its original value, and **Optimize** starts with a restore point.
- **Warns before trouble:** an optional icon near the clock warns when the disk fills up or shows signs of failing, protection turns off or maintenance is due.
- **Uses Windows' own tools:** Windows Update, Microsoft Defender, DISM, SFC, CHKDSK and winget, with no third-party "boosters".
- **Your data stays on your PC:** no account and no telemetry.

## Get started

1. Download **WinForge.zip** and extract the whole folder (right-click > **Extract All**).
2. Open **WinForge-Setup.cmd** and accept the Windows administrator prompt. WinForge shows up in the Start menu and in **Settings > Apps**.
3. Open WinForge. On **Home**, the health score tells you how the PC is doing, and two buttons take care of the rest:
   - **Check the PC** checks the PC in 11 steps and fixes what is safe with one click;
   - **Optimize** runs the full maintenance in 20 steps: the questions come first, then it carries on by itself. It can take more than an hour.

Rather not install? Open **WinForge.cmd** straight from the extracted folder.

## What it does

| Group | Pages | For example |
|---|---|---|
| **Care** | Maintenance, Cleanup, Performance | Quick cleanup, disk space analysis, duplicate files, what opens with Windows, scheduled maintenance |
| **Fix** | Repair, Diagnostics, Network | Repair Windows (DISM + SFC), CHKDSK, blue screens with the likely cause, memory test, disk health, network and DNS repair, stuck printing |
| **Protect** | Security, Updates | Protection status, security audit, BitLocker recovery key, Windows updates, drivers and programs |
| **Configure** | Programs, Windows tweaks, Personalization | Install and uninstall programs, backup before formatting, 53 Windows tweaks with ready-made profiles |

And also:

- **Tray monitor** (optional): warns before trouble, and clicking the warning opens the right action.
- **Change history** (in Maintenance): what WinForge changed on the PC, with undo for what can be undone.
- **Three languages:** Portuguese, English and Spanish, following the Windows language (choose it in **About WinForge > Language**).

## Requirements

- Windows 10 or 11, with the Windows PowerShell 5.1 that comes with it.
- Administrator rights for many of the actions. WinForge asks for them when it opens; without them, it opens anyway and asks again when an action needs them.
- App Installer (winget) to install, update and uninstall programs. It comes with Windows; if it is missing, WinForge offers to repair it.
- Internet only for what depends on it: updates, programs, network tests and checking for a new version.

## Security and privacy

> [!IMPORTANT]
> The scripts are not digitally signed, and Windows may warn you when opening them. Download only from the [releases page](https://github.com/guilhermehenn/winforge/releases) and, if you want, check the zip in PowerShell: the result must match the SHA-256 published on the version's page.
>
> ```powershell
> Get-FileHash .\WinForge.zip -Algorithm SHA256
> ```

- **Nothing from your PC is sent.** WinForge only goes online to look for a new version and to download the list of programs and the Windows support dates (from GitHub), and for the network tests you ask for (speed, connectivity and public IP). Everything else goes through the tools of Windows and of each program: Windows Update, Microsoft Defender, winget, the Microsoft Store and the browsers' own updaters.
- **Not everything can be undone:** what cleanup deletes and uninstalled programs do not come back through WinForge. That is why it asks first.
- **WinForge's data** (logs, reports and history) is kept in `%LOCALAPPDATA%\WinForge`. The backup before formatting does not copy your personal files and keeps the Wi-Fi passwords in plain text: protect the backup.

## Update and uninstall

- **Update:** **About WinForge > Check for a new version** downloads the new version, checks its SHA-256 and installs it with one click; WinForge closes and opens again already updated. If something fails midway, the previous files come back. With the tray monitor on, WinForge tells you when a new version is out. This works from 4.0 on: from an earlier version, install 4.0 with **WinForge-Setup.cmd**.
- **Uninstall:** from **Settings > Apps**, or by opening **WinForge-Setup.cmd** in the installed folder. It asks whether to also delete the data in `%LOCALAPPDATA%\WinForge`. Windows tweaks stay as they are: to go back, first use **Windows tweaks > Undo WinForge tweaks**.

## Command line

```powershell
.\WinForge-Console.cmd                      # terminal menu
.\WinForge-Console.cmd -Action Check -Json  # quick checkup, as JSON
.\WinForge-Console.cmd -Action Report       # HTML and text report
.\WinForge-Console.cmd -Language en         # pt, en or es
```

The quick checkup does not ask for administrator rights and gives the result in the exit code: 0 all good, 1 items need attention, 2 something critical, 3 could not be checked.

## FAQ

<details>
<summary><strong>Does WinForge make the PC faster?</strong></summary>

It removes what weighs on the PC for no reason (temporary files, what opens with Windows, programs weighing on it now), repairs Windows and keeps everything up to date. It does not promise a speed number: the gain depends on how the PC was.
</details>

<details>
<summary><strong>Does it replace my antivirus?</strong></summary>

No. WinForge's security uses Windows' own Microsoft Defender: it checks the protection, updates the signatures and runs the scan. With another antivirus installed, the Defender actions are left out.
</details>

<details>
<summary><strong>Something changed that I didn't want. How do I go back?</strong></summary>

In **Maintenance > Change history**, each change that can be undone has its undo. For all Windows tweaks at once, **Windows tweaks > Undo WinForge tweaks**. And the restore point that Optimize creates at the start brings the system back through Windows System Restore.
</details>

<details>
<summary><strong>Does it work without internet?</strong></summary>

Cleanup, diagnostics, tweaks and most repairs do. Updates, programs, network tests and checking for a new version need internet.
</details>

<details>
<summary><strong>Why does it ask for administrator rights?</strong></summary>

Repairing Windows, installing updates and changing system settings require them. If you decline, WinForge opens anyway, and the actions that need them show the shield and ask again.
</details>

## Help

Found a problem or have a suggestion? [Open an issue](https://github.com/guilhermehenn/winforge/issues/new). To help investigate a problem, include:

- The WinForge version and the Windows version and build.
- The interface used: window or terminal.
- The action you ran and the steps to reproduce the problem.
- What you expected and what happened instead.
- The full error message or a screenshot.

**About WinForge > Support package** puts the logs, the quick checkup and the latest report in a zip. Before sharing logs, reports or the package, review them and remove personal information.

## For developers

- [Technical documentation (in Portuguese)](https://github.com/guilhermehenn/winforge/blob/main/docs/documentacao-tecnica-4.0.md): how WinForge is built, where everything is and how to change the code. Newcomers start with "Comece por aqui" (start here).
- [Documentation index (in Portuguese)](https://github.com/guilhermehenn/winforge/blob/main/docs/README.md): the feature map, the 4.0 history and the review of each screen.
- `modules/`: the features; `gui/`: the window; `lang/`: the translations (gettext); `tools/`: signing, the release zip and translations.
- [What changed in each version (in Portuguese)](CHANGELOG.md) and the [detailed guide for build 3.69](https://github.com/guilhermehenn/winforge/blob/v3.69.0/README.md) (archived, in Portuguese).

## License

[GNU GPLv3](LICENSE) · © 2026 [Guilherme Henn](https://github.com/guilhermehenn), who maintains WinForge.
