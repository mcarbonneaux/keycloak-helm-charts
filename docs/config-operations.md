
## Operational Guides and Maintenance

To back up and restore Helm chart deployments on Kubernetes, you need to back up the persistent volumes from the source deployment and attach them to a new deployment using [Velero](https://velero.io/), a Kubernetes backup/restore tool.

### Resource requests and limits

This chart allows setting resource requests and limits for all containers inside the chart deployment. These are inside the `resources` value (check parameter table). Setting requests is essential for production workloads and these should be adapted to your specific use case.

To make this process easier, the chart contains the `resourcesPreset` values, which automatically sets the `resources` section according to different presets. However, in production workloads using `resourcesPreset` is discouraged as it may not fully adapt to your specific needs. Find more information on container resource management in the [official Kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).

### Set Pod affinity

This chart allows you to set your custom affinity using the `affinity` parameter. Find more information about Pod's affinity in the [kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity).

As an alternative, you can use of the preset configurations for pod affinity, pod anti-affinity, and node affinity. To do so, set the `podAffinityPreset`, `podAntiAffinityPreset`, or `nodeAffinityPreset` parameters.

### Label propagation with policy engines (e.g. Kyverno)

Some organizations use policy engines like [Kyverno](https://kyverno.io/) to automatically propagate labels from the namespace to all pods (e.g. for monitoring, alerting, or cost allocation purposes).

By default, such labels are added **after** pod creation, which creates a mismatch with the StatefulSet `selector.matchLabels`. This can cause the StatefulSet to lose track of its pods if the labels differ.

#### Recommended approach

Pre-declare those labels in `podLabels` with the **same values** that the policy engine would set. Since `podLabels` is included in both `selector.matchLabels` and `template.metadata.labels`, the pods already carry the expected labels before the policy engine runs — no conflict occurs.

```yaml
podLabels:
  my-org/team: platform
  my-org/env: production
  my-org/business-unit: identity
```

#### When namespace labels change

If the namespace labels are updated (e.g. a team or environment change), the policy engine will propagate the new values to new pods. This creates a **temporary mismatch** between the selector and the running pods:

- Existing pods continue to run normally (Keycloak stays available)
- The StatefulSet can no longer scale or replace crashed pods until the selector is updated

**Resolution**: run a `helm upgrade` with the updated `podLabels` values to realign the selector. A rolling restart will follow to apply the new labels to all pods.

> This scenario is expected to be rare (namespace label changes are infrequent) and is considered an acceptable operational trade-off.

### Add extra environment variables

In case you want to add extra environment variables (useful for advanced operations like custom init scripts), you can use the `extraEnvVars` property.

```yaml
extraEnvVars:
  - name: KEYCLOAK_LOG_LEVEL
    value: DEBUG
```

Alternatively, you can use a ConfigMap or a Secret with the environment variables. To do so, use the `extraEnvVarsCM` or the `extraEnvVarsSecret` values.

### Use Sidecars and Init Containers

If additional containers are needed in the same pod (such as additional metrics or logging exporters), they can be defined using the `sidecars` config parameter.

```yaml
sidecars:
- name: your-image-name
  image: your-image
  imagePullPolicy: Always
  ports:
  - name: portname
    containerPort: 1234
```

If these sidecars export extra ports, extra port definitions can be added using the `service.extraPorts` parameter (where available), as shown in the example below:

```yaml
service:
  extraPorts:
  - name: extraPort
    port: 11311
    targetPort: 11311
```

If additional init containers are needed in the same pod, they can be defined using the `initContainers` parameter. Here is an example:

```yaml
initContainers:
  - name: your-image-name
    image: your-image
    imagePullPolicy: Always
    ports:
      - name: portname
        containerPort: 1234
```

Learn more about [sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/) and [init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/).

### Initialize a fresh instance

The Keycloak image allows you to use your custom scripts to initialize a fresh instance. In order to execute the scripts, you can specify custom scripts using the `initdbScripts` parameter as dict.

In addition to this option, you can also set an external ConfigMap with all the initialization scripts. This is done by setting the `initdbScriptsConfigMap` parameter. Note that this will override the previous option.

The allowed extensions is `.sh`.

### Deploy extra resources

There are cases where you may want to deploy extra objects, such a ConfigMap containing your app's configuration or some extra deployment with a micro service used by your app. For covering this case, the chart allows adding the full specification of other objects using the `extraDeploy` parameter.

