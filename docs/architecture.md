### Workloads

- **[StatefulSet / Deployment](templates/statefulset.yaml)**: The main component. It can be configured as either a `StatefulSet` (default) or a `Deployment` via the `replicaKind` parameter.
    - **StatefulSet mode**: Ensures stable network identifiers, which is essential for standard JGroups discovery and internal Infinispan clustering.
    - **Deployment mode**: Can be used for better flexibility if an **external Infinispan cache** is configured (`cache.remote.host`).
        - **Clusterless Mode**: By setting `cache.remote.clusterless: true`, Keycloak runs without forming a JGroups cluster between pods. It relies entirely on the external Infinispan for state, which is the recommended way for `Deployment` workloads to achieve maximum scalability and zero JGroups-related overhead.
        - **Full Remote Mode**: When using `Deployment`, the chart automatically generates and applies a "Full Remote" Infinispan configuration. This disables local "Near Caches" and offloads all session-related data to the external server, making the Keycloak pods truly stateless.
- **[Init Containers](templates/_init_containers.tpl)**: Used to prepare the environment before Keycloak starts.
    - **prepare-write-dirs**: Copies necessary directories (`conf`, `data`, `providers`, `themes`) to temporary `emptyDir` volumes. This allows Keycloak to write to these directories even if the container root filesystem is read-only (standard in production).
- **[Keycloak Config CLI](templates/keycloak-config-cli-job.yaml)**: An optional `Job` that runs after installation or upgrade. It uses the `keycloak-config-cli` tool to automate the configuration of Realms, clients, and roles via YAML/JSON files without manual intervention in the admin console.

### Networking and Exposure

- **[Service](templates/service.yaml)**: The standard entry point for user traffic (HTTP/HTTPS). It load balances requests across the available Keycloak pods.
- **[Headless Service](templates/headless-service.yaml)**: A service without a virtual IP address used for pod discovery. It is critical for Keycloak instances to find each other and form an Infinispan cluster when using an internal cache stack.
- **[Ingress](templates/ingress.yaml)**: Exposes Keycloak outside the Kubernetes cluster via a domain name (FQDN) using the standard Ingress resource. It typically manages TLS termination (SSL).
- **[Gateway API](templates/gateway.yaml)**: An alternative to Ingress using the Kubernetes Gateway API (`HTTPRoute` resource). It provides more advanced traffic routing capabilities and better separation of concerns.

### Configuration and Secrets

- **[ConfigMaps](templates/configmap.yaml)**: Store non-sensitive configuration data:
    - Initialization scripts.
    - Environment variables for the Quarkus-based server.
    - Custom Keycloak configuration files.
- **[Secrets](templates/secrets.yaml)**: Store sensitive information securely:
    - Initial administrator credentials.
    - External database connection details.
    - External Infinispan cache credentials (if configured).
    - Keystores and Truststores for secure TLS communication.

### Scalability and Availability

- **[HPA (Horizontal Pod Autoscaler)](templates/hpa.yaml)**: Automatically adjusts the number of pods based on CPU or memory utilization.
- **[VPA (Vertical Pod Autoscaler)](templates/vpa.yaml)**: Automatically adjusts the CPU and RAM resources allocated to pods based on their actual consumption.
- **[PDB (Pod Disruption Budget)](templates/pdb.yaml)**: Guarantees that a minimum number of pods remain available during cluster maintenance operations (e.g., node upgrades).

### Observability

- **[ServiceMonitor / PrometheusRule](templates/servicemonitor.yaml)**: Provide native integration with the Prometheus Operator to collect performance metrics from Keycloak.
- **[Metrics Service](templates/metrics-service.yaml)**: A dedicated service for exposing Prometheus metrics, kept separate from user traffic for improved security.

### Security

- **[NetworkPolicy](templates/networkpolicy.yaml)**: Defines authorized network traffic rules to and from Keycloak, minimizing the potential attack surface.
- **[ServiceAccount](templates/serviceaccount.yaml)**: The identity under which Keycloak pods execute, allowing for specific permissions within the cluster when necessary.

### Database

This chart is designed to work with an **external database** (PostgreSQL by default). Connection parameters are injected via environment variables defined in the database `ConfigMap` and `Secret`.

