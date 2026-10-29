# Rebecca privacy

Rebecca is a client: you provide your own proxy configuration or subscription. It connects to those provider URLs to obtain configurations, and sends traffic through the server you select. Providers can observe connection metadata; choose a provider you trust.

This fork does not operate a Rebecca account service or subscription backend. It retains the upstream client features and their settings. Optional upstream integrations, diagnostics, update checks, IP checks, connectivity tests and Cloudflare WARP can contact third parties when enabled or used. Consult their policies before enabling them. Do not treat Rebecca as a promise of anonymity.

Configuration links and exports may contain credentials. Share them only with intended recipients. The source is available in this repository under LICENSE.md.
