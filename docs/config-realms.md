## Realm Configuration and Import/Export

#### Importing a realm

You can import a realm by setting the `extraStartupArgs` to contain the `--import-realm` argument.

This will import all `*.json` under `/opt/keycloak/data/import` files as a realm into keycloak as per the official documentation [here](https://www.keycloak.org/server/importExport#_importing_a_realm_from_a_directory). You can supply the files by mounting a volume (e.g., from a ConfigMap) as follows:

```yaml
extraVolumes:
  - name: keycloak-realms
    configMap:
      name: my-realms-configmap
extraVolumeMounts:
  - name: keycloak-realms
    mountPath: /opt/keycloak/data/import
    readOnly: true
extraStartupArgs: "--import-realm"
```

> **Note**: For a more automated and robust way to manage Keycloak configuration (realms, clients, roles, etc.), consider using the integrated `keycloak-config-cli` tool (see [Using keycloak-config-cli](#using-keycloak-config-cli) below).

### Using keycloak-config-cli

The chart includes a built-in Job that runs [keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli). This tool allows you to manage Keycloak configurations (realms, clients, users, etc.) using YAML/JSON files, and it applies these configurations via the Keycloak REST API.

#### How it works
The Job is configured to run as a Helm post-install and post-upgrade hook (by default if `useHelmHooks: true`). It will wait for the Keycloak service to be available before attempting to apply the configuration.

#### Example: Inline Configuration
You can define your realm configuration directly in your `values.yaml`:

```yaml
keycloakConfigCli:
  enabled: true
  configuration:
    my-realm.json: |
      {
        "realm": "my-realm",
        "enabled": true,
        "clients": [
          {
            "clientId": "my-client",
            "enabled": true
          }
        ]
      }
```

#### Example: Existing ConfigMap
If you prefer to manage your configuration files in a separate ConfigMap:

```yaml
keycloakConfigCli:
  enabled: true
  existingConfigmap: "my-config-cli-config"
```

The Job will automatically mount the files from the ConfigMap into `/config` and set `IMPORT_FILES_LOCATIONS=/config/*`.

#### Import/Export via API

Can I import/export via the API?

*   **Import**: Yes, `keycloak-config-cli` itself uses the Keycloak REST API to "import" (create/update) configurations. You can also use tools like `curl` to POST a realm JSON to the `/admin/realms` endpoint.
*   **Export**: Keycloak provides a REST API to get the representation of a realm, which effectively acts as an export.
    *   **GET** `/admin/realms/{realm}` returns the realm configuration in JSON.
    *   **Note**: Some sensitive data (like full user passwords or certain keys) might not be included in a simple API GET, unlike the `kc.sh export` command which can perform a full database dump.
*   **Comparison**:
    *   `kc.sh export/import`: Best for full backups/migrations (includes all users/hashes). Requires direct access to the database or running inside the container.
    *   `keycloak-config-cli` / API: Best for "Configuration as Code" and automation of realm settings, clients, and roles.

#### Exporting a realm

You can export a realm through the GUI, but it will not export users even if the option is set; this is a known Keycloak [bug](https://github.com/keycloak/keycloak/issues/23970).

To export a realm with users using the `kc.sh` script, you should first ensure you have a writable volume mounted (e.g., a PersistentVolumeClaim) to store the export:

```yaml
extraVolumes:
  - name: keycloak-export
    persistentVolumeClaim:
      claimName: keycloak-export-pvc
extraVolumeMounts:
  - name: keycloak-export
    mountPath: /export
```

Then, you can trigger the export by running the following command in a terminal connected to one of the running Keycloak pods:

```bash
kubectl exec -it <keycloak-pod-name> -- /opt/keycloak/bin/kc.sh export --dir /export/ --users realm_file
```

This will export all realms with users to the `/export` folder on the mounted volume.
