# Security policy

## Supported scope

Only the latest source on `main` is maintained. No response-time or vulnerability-free guarantee is offered.

Use GitHub's **Security → Report a vulnerability** private reporting feature when available. If it is unavailable, open an issue requesting a private contact without exploit details, credentials, personal information, logs, or serial numbers. Do not disclose a vulnerability publicly before maintainers can review it.

## Trust model

Windows, the installed Lenovo WMI provider, and administrator-approved source are trusted. A standard local user must not be able to replace code or redirect data subsequently used by the elevated scheduled task. Install only from an extracted, reviewed source tree; running the installer authorizes that source to execute as administrator.

The installer atomically creates protected fixed app code/data directories with Administrators/SYSTEM write permissions, rejects preexisting directories with untrusted ownership or write permissions, rejects reparse-point ancestors, and recreates known files instead of writing through preexisting hard links. SYSTEM, Administrators, and the installing administrator are trusted; UAC within that same administrator account is not treated as a security boundary. Windows' normal protected ancestor directories are assumed. It accepts only enumerated preferences and does not evaluate JSON as code. Do not loosen these ACLs or run the helper elevated directly from a shared writable folder. The source files are dynamically compiled code dependencies, not passive configuration.

The helper has no network surface or credential storage. Keyboard events are transient input to a wake policy; no typed text or key history is written. Local activity timestamps and errors are retained in a bounded log readable by local users. Treat those logs as potentially private usage metadata.

Intentional consumption of the wake key is a documented feature. Report suppression outside the long-dark wake gesture, hook cleanup failures, or input-disruption regressions. Report privileged path redirection, lower-privilege modification of installed code, unintended data collection, or arbitrary execution as security issues.

Hardware-specific correctness, unsupported keyboard APIs, and an administrator intentionally replacing trusted code are not by themselves privilege-boundary vulnerabilities. Do not test on someone else's device without permission.
