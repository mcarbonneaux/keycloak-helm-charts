# Changelog

# 2.0.0 — Major Refactor: Full Bitnami Departure & Enhanced Remote Infinispan Integration

---

## Summary
This release marks a turning point for the chart: we have **completely stripped away Bitnami dependencies** and shifted to the official Keycloak image. The core focus of this version is the **native support for Full Remote Infinispan architectures**, enabling true stateless deployments, multisite capabilities, and externalized session management.

---

### ⚠️ The "Exit Bitnami" Breaking Changes
* **Official Image Migration**: Switched from Bitnami-modified images to the **official** `quay.io/keycloak/keycloak:26.5.5`.
* **Zero Sub-chart Dependencies**: Fully removed `bitnami/common` and `bitnami/postgresql`.
* **Mandatory External DB**: An **external database is now required** (no bundled Postgres), using simplified flat configuration keys:
    * `dbHost` (Required), `dbPort`, `dbDatabase`, `dbUser`, `dbSchema`, `dbExistingSecret`.
* **Pure Ephemeral Storage**: Removed all PVCs and `storageClass` references; all internal volumes now use `emptyDir`.

### 🛰️ Enhanced Remote Cache & Infinispan Support
* **Full Remote Architecture**: Comprehensive support for external Infinispan clusters to handle sessions, allowing Keycloak to run in a truly stateless manner.
* **Clusterless Mode**: New `cache.remote.clusterless` parameter for high-scale deployments without JGroups.
* **Secure Connectivity**: Added `cache.remote.ssl` (default: `true`) for encrypted communication with remote cache providers.
* **Improved Authentication**: Full support for `digest` authentication and `server-name` configuration in remote cache XML.
* **Automated Config Mounting**: New init-container logic ensures that mounting an external `cache-ispn.xml` does not break the default Keycloak configuration directory.

### 🚀 Other New Features
* **Workload Flexibility**: Choose between `StatefulSet` or `Deployment` depending on your cache strategy.
* **Networking**: **Gateway API support** (`HTTPRoute`) and improved Ingress handling.
* **Observability**: Native **OpenTelemetry (OTel)** integration and structured **JSON logging**.

### 🛠 Critical Fixes & Stability
* **Remote Cache Logic**: Fixed `KC_CACHE` and `KC_CACHE_CONFIG_FILE` variables that were previously defaulting to "local" even when a remote host was specified.
* **Auth Fixes**: Resolved missing `KC_CACHE_REMOTE_USERNAME` when using `usePasswordFiles: true`.
* **Hostname Logic**: Fixed `KC_HOSTNAME_STRICT` to respect settings regardless of Ingress status.
* **Template Cleanup**: Removed invalid `podSecurityContext` fields and fixed YAML indentation errors in `statefulset.yaml` and `_helpers.tpl`.

### 📖 Documentation
* Guides for **Persistent Sessions** and **Multisite** scenarios.
* Full reference architecture for Kafka-based logging pipelines (Fluent Bit, Vector, OTel).
* Migration guide for users transitioning from the legacy Bitnami chart.

---

## Upstream Bitnami History (Reference)

### 25.x — 2025–2026
- **25.3.x**: Fix health probe paths with `httpRelativePath`; switch to official Keycloak endpoints (`/health/ready`, `/health/live`)
- **25.3.0**: New parameter `cache.javaOptsAppendExtra` for additional JVM options
- **25.2.x**: Fix duplicate secret labels; fix TLS ingress template indentation; fix metrics with `httpRelativePath`
- **25.2.0**: New parameter `externalDatabase.extraParams` for custom JDBC connection parameters
- **25.1.0**: New parameter `httpEnabled` to explicitly enable the HTTP endpoint
- **25.0.0** ⚠️ *Breaking*: Native metrics refactor; metrics service separated

### 24.x — 2025
- **24.9.0**: Support template values for `ingress.hostname` and `ingress.adminHostname`
- **24.8.0**: Support for custom database schema (`externalDatabase.schema`)
- **24.7.0**: Infinispan cache handling refactor (stack, config file, remote)
- **24.6.0**: Configurable availability check for `keycloak-config-cli`
- **24.5.0**: `usePasswordFiles=true` enabled by default (passwords mounted as files)
- **24.4.0**: Dedicated headless service for JGroups discovery (version-bound)
- **24.3.0**: Detection of non-standard images
- **24.0.0**: Major dependency update

### 23.x — 2024
- **23.0.0** ⚠️ *Breaking*: Bumped PostgreSQL to 17.x

### 22.x — 2024
- **22.2.0**: Use database user secret key from the PostgreSQL chart
- **22.1.0**: Support for Keycloak hostname v2 options
- **22.0.0**: Added `providers` and `themes` directories as writable dirs

### 21.x — 2024
- **21.8.0**: Support for GCE ingress controllers
- **21.7.0**: Support for `proxyHeaders` (forwarded/xforwarded)
- **21.6.0**: `minReadySeconds` parameter
- **21.5.0**: Added custom certificates to the system truststore
- **21.4.6**: Configurable `adminRealm` parameter
