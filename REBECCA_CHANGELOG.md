# Rebecca 0.0.2

- Transparent white, black and green versions of the approved Rebecca mark.
- Compact subscription headers with bounded actions and RTL layout regression tests.
- Per-architecture APK downloads instead of a universal APK containing all architectures.
- In-app release checking, user-approved installation and verified compact update patches.
- Android validates the package, increasing version and matching signing certificate before installation.

The previous 0.0.1 test build used an ephemeral debug signing key. Back up subscriptions before the one-time transition to the owner-signed version. Later releases use the same private signing key and retain application data during updates. Small patches are available when installed bytes match a supported earlier release; otherwise the app displays the full download size before downloading. Android confirmation remains required.
