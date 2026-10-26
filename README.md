# Lenovo Keyboard Idle

A small Windows tray utility that turns a compatible Lenovo laptop's keyboard backlight off when idle and restores it when you return.

**Tested hardware: Lenovo LOQ 15AHP10 (machine type 83JG), white backlit keyboard.** This is not a universal Fn + Space utility. Fn + Space is a firmware shortcut; sharing that shortcut does not mean another laptop exposes the same software interface.

## Features

- Right-click the blue information icon near the clock to select **1, 3, 5, 10, or 30 seconds**, or **1, 2, or 5 minutes**.
- Choose **Low** or **High** under **Back-on brightness**.
- Toggle **Mouse wakes keyboard**. When unchecked, keyboard input alone controls the idle timer and wake behavior.
- Toggle **First wake key doesn't type**. When enabled, after the backlight has been off for **15 seconds**, the next physical key press only wakes the light. That press, its repeats, and its release are consumed. Later keys type normally. When disabled, that first key types normally too.
- Independently toggle **Keep on for 15 seconds after long pause**. When enabled, waking after at least **15 seconds off** keeps the light on for **15 seconds**, then resumes the selected idle timeout. When disabled, the normal idle timeout applies immediately. Turning this option off cancels an active hold.
- A mouse wake after a long dark interval also gets the 15-second hold, if both mouse wake and the hold option are enabled. The next keyboard key then types normally.
- Preferences persist across restarts. The app starts at sign-in. **Exit** closes it until the next sign-in.

When first-key suppression is enabled, the wake key can be a modifier or shortcut key, and the hook can affect external keyboards in the same desktop session. Be aware of this behavior when entering shortcuts, passwords, or accessibility input. Synthetic input is not suppressed. Windows secure desktops and sign-in screens are outside the supported scope.

## Requirements and compatibility

- Windows 11, Windows PowerShell **5.1**, .NET Framework/Windows Forms, and Task Scheduler.
- An administrator account; Lenovo's WMI lighting provider requires elevation on the tested laptop.
- Installed Lenovo drivers exposing `root\wmi:LENOVO_LIGHTING_METHOD` with `Lighting_ID=0` and brightness levels **1 = off, 2 = low, 3 = high**.

The installer checks Lenovo manufacturer and lighting capability before changing the installation. Other Lenovo laptops with this exact interface may work, but are **unverified**. RGB keyboards, ThinkPads with different APIs, other vendors, and Fn + Space alone are not compatibility guarantees. The check confirms a readable interface; it cannot guarantee every model's write behavior. Brightness changes are checked by reading them back.

## Install

1. Download the repository ZIP from GitHub or clone it, then extract it fully.
2. Review the source and scripts. Do not run a remote script through `Invoke-Expression` or a pipe.
3. Open **Windows PowerShell as administrator**, using the Windows account that should run the app.
4. Change to the extracted repository folder and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

`Bypass` applies only to this process; the installer does not change your permanent execution policy or Windows security settings. Organizational policy may prevent unsigned scripts; follow your organization's policy rather than bypassing its protections.

The installer copies the three source files to `%ProgramFiles%\KeyboardIdleBacklight`, provisions `%ProgramData%\KeyboardIdleBacklight`, and registers the **Lenovo Keyboard Idle** scheduled task. The task runs elevated in the installing user's interactive session; it does not store a password. It starts immediately and at subsequent sign-ins, including on battery power.

Default preferences for a new installation are **10 seconds**, **Low**, **mouse wake enabled**, **first wake key doesn't type enabled**, and **15-second hold enabled**. All five preferences are saved; upgrades without the new options retain the previous enabled behavior. The tray icon may appear under the **^** overflow arrow. If you install while signed in as a different administrator, startup belongs to that administrator; install using your intended Windows account.

## Update and uninstall

Run `Install.ps1` again from a freshly reviewed copy. It replaces the app files and preserves valid preferences. It also replaces the original prototype task named `Keyboard Backlight - 60 Second Idle`, if present. Updates stop the app briefly and clear the local activity log.

From an administrator PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
# Also remove preferences and the activity log:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1 -RemoveSettings
```

Uninstall removes the known app files and startup tasks and attempts to restore Low brightness. It leaves empty folders and unrelated files alone. **Exit** is a temporary stop, not an uninstall. A forced process stop cannot run cleanup; Fn + Space remains available if the light stays off.

## Security and privacy

- The installed helper has **no network client, listener, telemetry, automatic updater, or downloaded runtime dependencies**. GitHub and CI are used for source hosting and tests, not by the installed helper.
- Typed text and keystroke history are **not recorded or transmitted**. The keyboard hook sees event metadata and holds one virtual-key identifier temporarily to suppress the wake press. It retains an activity timestamp.
- The bounded local `activity.log` records state transitions, timestamps, brightness, preference changes, and errors. Those timestamps reveal usage patterns. Do not post your log publicly without reviewing it.
- The installer creates protected code/data folders atomically, with Administrators and SYSTEM write access and Users read/execute access. It rejects preexisting folders with an untrusted owner or write permissions, symbolic links, and junctions. It recreates known output files instead of overwriting preexisting hard links. An existing folder owned or writable by the installing administrator is trusted; this does not claim a security boundary between that administrator's elevated and unelevated processes.
- JSON preferences are parsed as data and restricted to supported values. Adjacent C# files are compiled locally with `Add-Type`; modifying those files is equivalent to modifying the elevated app.
- The low-level hook runs on a dedicated message thread, separate from WMI hardware calls. It is removed on normal exit. This is sensitive input-handling software: use source you trust and keep the installed folder protected.

This is a small community utility, not a signed Lenovo product or a security-certified application. Static review and tests reduce risk; they do not establish that software is vulnerability-free. See [SECURITY.md](SECURITY.md) for reporting and the trust model.

## Development and verification

No package manager or third-party test framework is required:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

Tests check the long-dark threshold, consumed key repeat/release, subsequent normal typing, prolonged hold, Low/High state transitions, mouse selection, junction rejection, PowerShell syntax, and C# compilation. The automated suite does **not** install a keyboard hook, alter the real backlight, install the task, or prove hardware compatibility.

An additional administrator-only test checks protected directory creation, racing existing-path refusal, and rejection of writable existing directories. It creates and removes an empty temporary directory under ProgramData; it does not install the app:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\AdminProvisioning.Tests.ps1
```

The working prototype was exercised on the tested laptop. The packaged install/uninstall scripts have static review and path-control tests; a clean-machine install, every Windows input method, lock/unlock, sleep/resume, and other laptop models have not all been tested. Please report compatibility with model, Windows version, and white/RGB keyboard type—never with serial numbers or passwords.

## Source layout

| File | Purpose |
| --- | --- |
| `src/KeyboardIdleBacklight.ps1` | WMI lighting, preferences, tray menu, timer |
| `src/KeyboardActivityClock.cs` | Dedicated keyboard hook and activity clock |
| `src/WakeKeyPolicy.cs` | First-key suppression and 15-second hold policy |
| `Install.ps1`, `Maintenance.ps1`, `Uninstall.ps1` | Capability check, protected deployment, startup, removal |
| `tests/` | Hardware-independent regression checks |

Licensed under the [MIT License](LICENSE).
