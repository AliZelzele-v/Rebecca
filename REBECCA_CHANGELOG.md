# Rebecca 0.0.3

- Three mobile sections: Home, Configurations and Settings.
- Persistent connection control using the original engine state.
- Home tunnel dashboard uses real transfer statistics and available exit-IP metadata. Unknown information is not fabricated.
- Optional stable server sorting by valid measured ping; failures and unmeasured servers remain at the end. The selected server is not changed by sorting.
- Preserve upstream connection, routing and settings behavior.
- Build dependency: replace the unavailable mutable draft core artifact with the official stable v5.1.0 Android artifact, pinned by SHA-256. This changes native core bytes; compatibility is checked by Android compilation.

Visual inspiration: the owner-provided screenshots and 2dust/v2rayNG MainActivity/MainViewModel. Kotlin/Compose code is not embedded into the Flutter app. No new VPN engine or server was introduced.
