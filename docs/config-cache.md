
## Cache and Cluster Configuration

Keycloak uses **Infinispan** to manage its caches (sessions, tokens, brute-force authentication, etc.). The "stack" defines the communication and discovery protocol used by JGroups to form a cluster between different Keycloak pods.

#### Cache Stack Options

You can configure the `cache.stack` parameter in your `values.yaml`. Here are the available options:

- **`jdbc-ping` (Default in this chart)**: The most robust configuration for Kubernetes when using a relational database.
    - **How it works**: Keycloak instances use a dedicated table in the SQL database to register their presence and discover other cluster members.
    - **Pros**: Highly reliable, does not require complex RBAC permissions for the Kubernetes API.
- **`kubernetes`**: Uses native Kubernetes mechanisms for discovery (often using `DNS_PING` or `KUBERNETES_PING`).
    - **How it works**: JGroups queries the Kubernetes API to list pods matching certain labels or services, or uses DNS records of a headless service. This chart automatically configures `DNS_PING` through the `JAVA_OPTS_APPEND` environment variable using a headless service (`-Djgroups.dns.query=...`).
    - **Prerequisites**: If using `KUBERNETES_PING`, you must enable RBAC creation by setting `serviceAccount.rbac.create=true`. This will create a `Role` and `RoleBinding` allowing the Keycloak pod to `get` and `list` pods in its namespace. `DNS_PING` only requires access to the DNS service.
- **`udp` (IP Multicast)**:
    - **How it works**: Uses IP multicast for discovery and communication.
    - **Caution**: Most Cloud networks (AWS VPC, Azure VNET, Google VPC) and many Kubernetes CNIs (like Calico or Flannel in some configurations) do not support multicast. Use only if you have full control over your network layer.
- **`tcp`**:
    - **How it works**: Uses direct TCP connections between pods.
    - **Configuration**: Often requires manually listing IP addresses (via `TCPPING`) or using an external discovery mechanism.
- **Cloud-specific stacks (`ec2`, `azure`, `google`)**:
    - Stacks designed for specific cloud providers if you are running Keycloak directly on VMs, using provider-specific APIs for discovery (e.g., AWS S3_PING).

#### External Infinispan Cache

If you need to connect to an external Infinispan server, you can use the `cache.remote.*` parameters. This allows Keycloak to offload its caching to a dedicated cluster.

```yaml
cache:
  remote:
    host: "external-infinispan-server"
    port: 11222
    username: "cache-user"
    password: "cache-password"
```

> **Note**: Even when using an external Infinispan cache, the local `cache.stack` still defines how Keycloak pods communicate with each other for local L1 caching or coordination. `jdbc-ping` remains a recommended default.

#### Deployment Scenarios

This chart supports four main deployment scenarios:

##### Scenario 1: Default Mode (StatefulSet with Internal Cache)

This is the **default configuration** suitable for most single-cluster deployments.

**Use cases:**
- Standard Keycloak deployment
- Single Kubernetes cluster
- No external cache infrastructure required
- Development and testing environments

**Configuration:**

```yaml
# Default values - no special configuration needed
dbHost: postgres.example.com
# StatefulSet is the default replicaKind
# Internal Infinispan cache is enabled by default
```

**Characteristics:**
- Uses `StatefulSet` for stable network identities
- Internal Infinispan cache using `jdbc-ping` for discovery
- JGroups cluster formed between Keycloak pods
- Headless service for pod discovery
- Sessions stored in-memory across the cluster
- **Storage:** No PVCs - uses `emptyDir` volumes only (ephemeral, local storage)

> **Note:** Despite using StatefulSet, this chart does **not** use PersistentVolumeClaims. All data is stored in the external database (PostgreSQL), and only temporary runtime files use `emptyDir` volumes on the node's local disk. No StorageClass configuration is required.

##### Scenario 2: Clusterless Mode (Stateless Keycloak)

In this mode, Keycloak pods do not form a JGroups cluster. All session data is stored in the external Infinispan cluster, making Keycloak pods completely stateless.

**Use cases:**
- Maximum horizontal scalability
- Zero JGroups networking overhead
- Simplified network policies
- Best for high-traffic, single-site deployments

**Configuration:**

```yaml
replicaKind: Deployment  # Use Deployment instead of StatefulSet
cache:
  enabled: true
  remote:
    host: "infinispan.example.com"
    port: 11222
    username: "keycloak"
    password: "secret"
    clusterless: true  # Disables JGroups clustering
```

**Characteristics:**
- Uses `Deployment` for better scalability
- `KC_CACHE` is set to `local` (no JGroups cluster formation)
- No headless service is created for JGroups discovery
- RBAC permissions for Kubernetes API are not required
- Keycloak pods are fully stateless and can be scaled dynamically
- **Storage:** Same as Scenario 1 - only `emptyDir` volumes (no PVCs, no StorageClass needed)

##### Scenario 3: Persistent User Sessions (Hybrid Caching)

In this mode, Keycloak pods maintain a local JGroups cluster for coordination but persist all session data to the external Infinispan.

**Use cases:**
- Session persistence across pod restarts
- Active-active deployments with shared sessions
- Backup and recovery scenarios

**Configuration:**

```yaml
replicaKind: Deployment  # Can use Deployment for better flexibility
cache:
  enabled: true
  stack: jdbc-ping
  remote:
    host: "infinispan.example.com"
    port: 11222
    username: "keycloak"
    password: "secret"
    clusterless: false  # Maintains JGroups cluster
```

**Characteristics:**
- Uses `Deployment` for flexibility
- The chart automatically generates a "Full Remote" Infinispan configuration
- All session caches (`sessions`, `authenticationSessions`, `offlineSessions`, etc.) are stored remotely
- Local caches for immutable data (`realms`, `users`, `authorization`) remain replicated
- JGroups cluster is maintained for coordination between Keycloak pods
- `KC_CACHE_CONFIG_FILE` is set to `/opt/keycloak/conf/cache-ispn-full-remote.xml`
- **Storage:** Same as other scenarios - only `emptyDir` volumes (no PVCs, no StorageClass needed)

##### Scenario 4: Multisite Deployment (Clusterless + Persistent Sessions)

Combines clusterless mode with persistent sessions for multi-datacenter or multi-region deployments.

**Use cases:**
- Active-active multi-datacenter deployments
- Geographic load balancing
- Disaster recovery with session continuity
- Global user session sharing

**Configuration:**

Deploy the same configuration in multiple sites, all pointing to the same external Infinispan cluster:

**Site A:**
```yaml
replicaKind: Deployment
cache:
  enabled: true
  remote:
    host: "infinispan-global.example.com"  # Shared Infinispan cluster
    port: 11222
    username: "keycloak"
    password: "secret"
    clusterless: true
```

**Site B:**
```yaml
replicaKind: Deployment
cache:
  enabled: true
  remote:
    host: "infinispan-global.example.com"  # Same Infinispan cluster
    port: 11222
    username: "keycloak"
    password: "secret"
    clusterless: true
```

**Characteristics:**
- Each site runs independent Keycloak deployments (no JGroups between sites)
- All sites share the same external Infinispan cluster
- User sessions are globally accessible across all sites
- Sites can fail independently without affecting others
- Users can be redirected to any site without losing their session
- Same as Scenario 2 (Clusterless) but with multiple geographic deployments
- **Storage:** Same as other scenarios - only `emptyDir` volumes (no PVCs, no StorageClass needed)

**Infinispan Requirements for Multisite:**
- Infinispan cluster must be accessible from all sites
- Consider using Infinispan Cross-Site Replication for geo-distributed deployments
- Ensure low-latency network connectivity between sites and Infinispan
- Configure appropriate cache consistency levels (e.g., `STRONG`, `WEAK`)

> **Important**: For production multisite deployments, consider using Infinispan's Cross-Site Replication feature to deploy Infinispan clusters in each datacenter with automatic replication between them.

#### Scenarios Comparison Table

| Aspect | Scenario 1<br>(Default) | Scenario 2<br>(Clusterless) | Scenario 3<br>(Persistent) | Scenario 4<br>(Multisite) |
|--------|-------------------------|----------------------------|---------------------------|---------------------------|
| **Workload Type** | StatefulSet | Deployment | Deployment | Deployment |
| **External Infinispan** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **JGroups Cluster** | ✅ Yes | ❌ No | ✅ Yes | ❌ No |
| **Session Storage** | In-memory | External | External | External (global) |
| **Scalability** | Medium | High | High | Very High |
| **Network Overhead** | Medium | Low | Medium | Low |
| **Use Case** | Single cluster | Single site, high scale | Active-active | Multi-datacenter |
| **PVCs Required** | ❌ No | ❌ No | ❌ No | ❌ No |
| **StorageClass** | ❌ Not needed | ❌ Not needed | ❌ Not needed | ❌ Not needed |
| **Storage Type** | `emptyDir` | `emptyDir` | `emptyDir` | `emptyDir` |

> **Important:** All scenarios use **ephemeral `emptyDir` volumes** for temporary runtime files only. Keycloak state is stored in the external PostgreSQL database and (for scenarios 2-4) sessions in external Infinispan. No persistent volumes or StorageClass configuration is required.

#### Custom Configuration File

If none of the default stacks fit your needs, you can provide a complete custom Infinispan configuration file:

1. Set `cache.configFile: "my-config.xml"`.
2. Mount this file into the pod (via a volume or custom image) at `/opt/keycloak/conf/`.

#### Providing your own TLS secret

To provide your own secret set the `tls.existingSecret` value. It is possible to use PEM or JKS.

To use PEM Certs:

- `tls.usePemCerts=true`: Use PEM certificates instead of a JKS file.
- `tls.certFilename`: Certificate filename. Defaults to `tls.crt`.
- `tls.certKeyFilename`: Certificate key filename. Defaults to `tls.key`

To use JKS keystore:

- `tls.usePemCerts=false`: Use JKS file.
- `tls.keystoreFilename`: Certificate filename. Defaults to `keycloak.keystore.jks`.
- `tls.truststoreFilename`: Truststore filename. Defaults to `keycloak.truststore.jks`.

In the following example we will use PEM certificates. First, create the secret with the certificates files:

```console
kubectl create secret generic certificates-tls-secret --from-file=./cert.pem --from-file=./cert.key
```

Then, use the following parameters:

```console
tls.enabled=true
tls.autoGenerated.enabled=false
tls.usePemCerts=true
tls.existingSecret="certificates-tls-secret"
tls.certFilename="cert.pem"
tls.certKeyFilename="cert.key"
```

#### Auto-generation of TLS certificates

It is also possible to rely on the chart certificate auto-generation capabilities. The chart supports two different ways to auto-generate the required certificates:

- Using Helm capabilities. Enable this feature by setting `tls.autoGenerated.enabled` to `true` and `tls.autoGenerated.engine` to `helm`.
- Relying on CertManager (please note it's required to have CertManager installed in your K8s cluster). Enable this feature by setting `tls.autoGenerated.enabled` to `true` and `tls.autoGenerated.engine` to `cert-manager`. Please note it's supported to use an existing Issuer/ClusterIssuer for issuing the TLS certificates by setting the `tls.autoGenerated.certManager.existingIssuer` and `tls.autoGenerated.certManager.existingIssuerKind` parameters.

#### Use with ingress offloading SSL

If your ingress controller has the TLS/SSL Termination, you might need to properly configure the reverse proxy headers via the `proxyHeaders` parameter. Find more information in the [upstream documentation](https://www.keycloak.org/server/reverseproxy).

### Update credentials

Charts configure credentials at first boot. Any further change in the secrets or credentials require manual intervention. Follow these instructions:

- Update the user password 
- following [the upstream documentation](https://www.keycloak.org/server/configuration)
- Update the password secret with the new values (replace the SECRET_NAME and PASSWORD placeholders)

```shell
kubectl create secret generic SECRET_NAME --from-literal=admin-password=PASSWORD --dry-run -o yaml | kubectl apply -f -
```
