
## Observability, Metrics and Logging Configuration

This chart can be integrated with Prometheus by setting `metrics.enabled` to `true`. This will expose Keycloak native Prometheus endpoint in a `metrics` service, which can be configured under the `metrics.service` section. It will have the necessary annotations to be automatically scraped by Prometheus.

#### Prometheus requirements

It is necessary to have a working installation of Prometheus or Prometheus Operator for the integration to work.

#### Integration with Prometheus Operator

The chart can deploy `ServiceMonitor` objects for integration with Prometheus Operator installations. To do so, set the value `metrics.serviceMonitor.enabled=true`. Ensure that the Prometheus Operator `CustomResourceDefinitions` are installed in the cluster or it will fail with the following error:

```text
no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

### Logging Configuration for ELK/Observability Stack

Keycloak supports JSON-formatted logs which are ideal for integration with modern observability stacks like ELK (Elasticsearch, Logstash, Kibana), Grafana Loki, or other open-source log aggregation systems.

#### Enable JSON / ECS Logging

To enable JSON-formatted or ECS (Elastic Common Schema) logs for stdout/stderr, configure the `logging.output` parameter:

```yaml
logging:
  output: json  # Options: "default", "json" or "ecs"
  level: INFO   # Options: FATAL, ERROR, WARN, INFO, DEBUG, TRACE, ALL, OFF
```

Or via Helm command line:

```bash
helm install keycloak . \
  --set dbHost=postgres.example.com \
  --set logging.output=ecs \
  --set logging.level=INFO
```

**Environment variables generated:**
- `KC_LOG_CONSOLE_OUTPUT=ecs` - Enables ECS format (or `json`, `default`)
- `KC_LOG_LEVEL=INFO` - Sets log level

#### Enable OpenTelemetry (OTLP) Logging (Keycloak 24+)

Since Keycloak 24, OpenTelemetry (OTLP) logging is available as a preview feature. You can enable it directly via the chart:

```yaml
logging:
  otelEnabled: true
  otelEndpoint: "http://otel-collector:4317"
features:
  - opentelemetry-logs
```

Or via Helm command line:

```bash
helm install keycloak . \
  --set logging.otelEnabled=true \
  --set logging.otelEndpoint="http://otel-collector:4317" \
  --set features[0]=opentelemetry-logs
```

**Environment variables generated:**
- `KC_TELEMETRY_LOGS_ENABLED=true` - Enables OTLP logging
- `KC_OTEL_ENDPOINT=http://otel-collector:4317` - Collector endpoint
- `KC_FEATURES=opentelemetry-logs` - Enables the preview feature

#### JSON / ECS Log Format Examples

When `logging.output=json` is set, Keycloak outputs structured JSON logs:

```json
{
  "timestamp": "2024-01-15T10:30:45.123Z",
  "sequence": 12345,
  "loggerClassName": "org.keycloak.services.managers.AuthenticationManager",
  "loggerName": "org.keycloak.events",
  "level": "INFO",
  "message": "User 'admin' authenticated successfully",
  "threadName": "executor-thread-1",
  "threadId": 42,
  "mdc": {
    "realmId": "master",
    "userId": "abc-123"
  }
}
```

When `logging.output=ecs` is set, Keycloak outputs logs in **Elastic Common Schema (ECS)** format, which simplifies integration with ELK without extra transformations:

```json
{
  "@timestamp": "2024-01-15T10:30:45.123Z",
  "log.level": "INFO",
  "message": "User 'admin' authenticated successfully",
  "ecs.version": "1.12.0",
  "log.logger": "org.keycloak.events",
  "process.thread.name": "executor-thread-1",
  "labels": {
    "realmId": "master",
    "userId": "abc-123"
  }
}
```

#### Integration with Log Collection and ELK Stack

This chart is designed to work with modern log collection architectures. JSON logs from stdout/stderr are automatically collected by Kubernetes-native log collectors.

**Recommended Architecture:**

```
┌─────────────────┐
│ Keycloak Pods   │
│ (JSON stdout)   │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│  Log Collectors (DaemonSet per node)   │
│  • Fluent Bit (lightweight)             │
│  • Vector (high performance)            │
│  • OpenTelemetry Collector (new)        │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│  Kafka Topics   │ ◄─── Buffering, routing, replay
│  (log streams)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ELK Stack      │
│  • Logstash     │ ◄─── Kafka consumers
│  • Elasticsearch│
│  • Kibana       │
└─────────────────┘
```

#### Option 1: Fluent Bit (Lightweight, Production-Ready)

**Fluent Bit DaemonSet Configuration:**

Fluent Bit automatically collects logs from all pods on each node. When using `logging.output=ecs`, no custom parser is needed as logs are already in a standard format:

```yaml
# fluent-bit-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Log_Level     info

    [INPUT]
        Name              tail
        Tag               kube.keycloak.*
        Path              /var/log/containers/keycloak-*_*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     5MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [FILTER]
        Name                kubernetes
        Match               kube.keycloak.*
        Kube_URL            https://kubernetes.default.svc:443
        Merge_Log           On
        K8S-Logging.Parser  On

    [OUTPUT]
        Name          kafka
        Match         kube.keycloak.*
        Brokers       kafka-broker-1:9092,kafka-broker-2:9092,kafka-broker-3:9092
        Topics        logs-keycloak
        Topic_Key     kubernetes.namespace_name
        Retry_Limit   3
```

**Enable ECS logging in Keycloak:**
```yaml
logging:
  output: ecs
  level: INFO
```

#### Option 2: Vector (High Performance, Modern)

**Vector DaemonSet Configuration:**

Vector is a next-generation observability data pipeline with excellent performance. With `logging.output=ecs`, the configuration is minimal:

```yaml
# vector-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vector-config
  namespace: logging
data:
  vector.toml: |
    # Source: Kubernetes logs
    [sources.kubernetes_logs]
      type = "kubernetes_logs"
      auto_partial_merge = true
      self_node_name = "${VECTOR_SELF_NODE_NAME}"

    # Transform: Parse ECS logs from Keycloak
    [transforms.parse_keycloak]
      type = "remap"
      inputs = ["kubernetes_logs"]
      source = '''
        if contains(string!(.file), "keycloak") {
          . = merge(., parse_json!(string!(.message))) ?? .
          .service.name = "keycloak"
          .orchestrator.type = "kubernetes"
          .orchestrator.namespace = .kubernetes.namespace_name
          .orchestrator.resource.name = .kubernetes.pod_name
        }
      '''

    # Sink: Kafka
    [sinks.kafka_keycloak]
      type = "kafka"
      inputs = ["parse_keycloak"]
      bootstrap_servers = "kafka-broker-1:9092,kafka-broker-2:9092,kafka-broker-3:9092"
      topic = "logs-keycloak-{{ kubernetes.namespace_name }}"
      encoding.codec = "json"
      compression = "snappy"

      # Buffer configuration
      buffer.type = "disk"
      buffer.max_size = 268435488  # 256 MiB
      buffer.when_full = "block"
```

**Deploy Vector:**
```bash
helm repo add vector https://helm.vector.dev
helm install vector vector/vector \
  --namespace logging \
  --set role=Agent \
  --set customConfig=vector-config
```

#### Option 3: OpenTelemetry Collector (Cloud-Native, Vendor-Neutral)

**OpenTelemetry Collector Configuration:**

Recommended for new clusters with OpenTelemetry standardization. Using `logging.output=ecs` simplifies the processing:

```yaml
# otel-collector-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: logging
data:
  otel-collector-config.yaml: |
    receivers:
      filelog:
        include:
          - /var/log/pods/*/keycloak-*/*.log
        operators:
          # Parse CRI-O/containerd format
          - type: regex_parser
            regex: '^(?P<time>[^\s]+) (?P<stream>stdout|stderr) (?P<logtag>[^\s]*) (?P<log>.*)$'
          # Parse Keycloak ECS log
          - type: json_parser
            parse_from: attributes.log
            parse_to: body

    processors:
      batch:
        timeout: 10s
      resource:
        attributes:
          - key: service.name
            value: keycloak
            action: upsert

    exporters:
      kafka:
        brokers:
          - kafka-broker-1:9092
        topic: logs-keycloak
        encoding: json

    service:
      pipelines:
        logs:
          receivers: [filelog]
          processors: [batch, resource]
          exporters: [kafka]
```

#### Kafka to ELK Pipeline

**Logstash Kafka Consumer Configuration:**

Consume Keycloak logs from Kafka and index to Elasticsearch.

```ruby
# logstash-keycloak.conf
input {
  kafka {
    bootstrap_servers => "kafka-broker-1:9092,kafka-broker-2:9092,kafka-broker-3:9092"
    topics => ["logs-keycloak"]
    group_id => "logstash-keycloak-consumer"
    consumer_threads => 4
    codec => "json"
    decorate_events => true
    auto_offset_reset => "latest"
  }
}

filter {
  # Add index name based on namespace
  mutate {
    add_field => {
      "[@metadata][target_index]" => "keycloak-%{[kubernetes][namespace_name]}-%{+YYYY.MM.dd}"
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch-master:9200"]
    index => "%{[@metadata][target_index]}"
    template_name => "keycloak-logs"
    template_overwrite => true
  }
}
```

#### Alternative: Grafana Loki (Lightweight, Open Source)

If using Grafana Loki instead of the Kafka + ELK stack, you have multiple integration options:

**Option 1: Promtail DaemonSet → Loki**

```yaml
# promtail-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: logging
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod

        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            action: keep
            regex: keycloak

          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace

          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod

        pipeline_stages:
          - json:
              expressions:
                timestamp: timestamp
                level: level
                logger: loggerName
                message: message
                thread: threadName
                mdc: mdc

          - labels:
              level:
              logger:

          - timestamp:
              source: timestamp
              format: RFC3339Nano
```

**Enable JSON logging:**
```yaml
logging:
  output: json
  level: INFO
```

**Option 2: Kafka → Loki (Unified with ELK Architecture)**

Use Promtail as a Kafka consumer to integrate with your existing Kafka infrastructure:

```yaml
# promtail-kafka-consumer.yaml
scrape_configs:
  - job_name: kafka-keycloak-logs
    kafka:
      brokers:
        - kafka-broker-1:9092
        - kafka-broker-2:9092
        - kafka-broker-3:9092
      topics:
        - logs-keycloak
      group_id: promtail-loki-consumer
      version: 2.8.0
      use_incoming_timestamp: false

    relabel_configs:
      - source_labels: [__kafka_topic]
        target_label: topic
      - source_labels: [__kafka_partition]
        target_label: partition

    pipeline_stages:
      - json:
          expressions:
            level: level
            logger: loggerName
            message: message
            namespace: kubernetes.namespace_name

      - labels:
          level:
          namespace:
```

This allows you to use both Loki and ELK simultaneously from the same Kafka stream.

#### ECS (Elastic Common Schema) Format

Since Keycloak 24+, the Elastic Common Schema (ECS) format is supported natively. This is the simplest and recommended way to integrate with the ELK stack as it provides a standardized JSON structure without requiring custom parsers or image modifications.

To enable it, set `logging.output=ecs` in your values or via `--set logging.output=ecs`.

#### Recommended Log Levels

| Environment | Level | Use Case |
|-------------|-------|----------|
| **Production** | `INFO` | Standard operations, errors, warnings |
| **Staging** | `DEBUG` | Troubleshooting, detailed flow |
| **Development** | `DEBUG` or `TRACE` | Development and debugging |
| **Performance Testing** | `WARN` | Reduce log volume during load tests |

#### Log Volume Considerations

- **`INFO` level**: ~500 KB/hour per pod (normal traffic)
- **`DEBUG` level**: ~5-10 MB/hour per pod
- **`TRACE` level**: ~50+ MB/hour per pod

Adjust log retention policies in your ELK stack accordingly.

#### Accessing Logs

**Real-time logs (kubectl):**
```bash
# Raw JSON logs
kubectl logs -f deployment/keycloak -n keycloak | jq .

# Pretty-print with key fields
kubectl logs -f deployment/keycloak -n keycloak | jq '{timestamp, level, logger: .loggerName, message}'
```

**Kibana Query Examples (Standard JSON):**

```
# Find authentication failures
level: "WARN" AND message: "Failed login"

# Track specific user
mdc.userId: "abc-123"

# Find slow requests
message: "slow" AND level: "WARN"
```

**Kibana Query Examples (ECS Format):**

```
# Authentication failures (ECS)
log.level: "ERROR" AND service.name: "keycloak" AND event.category: "authentication"

# Track specific user (ECS)
user.id: "abc-123" AND service.name: "keycloak"

# All logs from specific namespace (ECS)
orchestrator.namespace: "production" AND service.name: "keycloak"

# High severity logs (ECS)
log.syslog.severity.code: [0 TO 3] AND service.name: "keycloak"

# Specific realm activity (ECS)
labels.realm: "master" AND event.category: "authentication"
```

**Example ECS Log Entry:**

When using Logstash ECS transformation, logs will look like:

```json
{
  "@timestamp": "2024-01-15T10:30:45.123Z",
  "ecs": {
    "version": "8.11"
  },
  "service": {
    "name": "keycloak",
    "type": "identity",
    "realm": "master"
  },
  "log": {
    "level": "INFO",
    "logger": "org.keycloak.events",
    "original": "User 'admin' authenticated successfully",
    "syslog": {
      "severity": {
        "code": 6
      }
    }
  },
  "message": "User 'admin' authenticated successfully",
  "user": {
    "id": "abc-123"
  },
  "process": {
    "thread": {
      "name": "executor-thread-1",
      "id": 42
    }
  },
  "orchestrator": {
    "type": "kubernetes",
    "namespace": "production",
    "resource": {
      "name": "keycloak-deployment-abc123-xyz"
    }
  },
  "container": {
    "name": "keycloak",
    "runtime": "containerd"
  },
  "labels": {
    "realm": "master",
    "environment": "production",
    "cluster": "eu-west-1"
  },
  "event": {
    "kind": "event",
    "category": "authentication"
  }
}
```

> **Note:** Keycloak logs are written to **stdout/stderr only**. No log files are written to disk. All logging happens in-memory and is immediately available for collection by your log aggregator.
