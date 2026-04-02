{{/*
Copyright 2020-2026 Broadcom, Inc. All Rights Reserved.
Copyright 2026 Mathieu CARBONNEAUX
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Returns an init-container that copies writable directories to an empty dir volume in order to not break the application functionality
*/}}
{{- define "keycloak.defaultInitContainers.prepareWriteDirs" -}}
- name: prepare-write-dirs
  image: {{ template "keycloak.image" . }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  {{- if .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.enabled }}
  securityContext:
    {{- if .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.runAsUser }}
    runAsUser: {{ .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.runAsUser }}
    {{- end }}
    {{- if .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.runAsNonRoot }}
    runAsNonRoot: {{ .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.runAsNonRoot }}
    {{- end }}
    {{- if .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.allowPrivilegeEscalation }}
    allowPrivilegeEscalation: {{ .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.allowPrivilegeEscalation }}
    {{- end }}
    {{- if .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.readOnlyRootFilesystem }}
    readOnlyRootFilesystem: {{ .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.readOnlyRootFilesystem }}
    {{- end }}
    {{- if .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.capabilities }}
    capabilities: {{- include "common.tplvalues.render" (dict "value" .Values.defaultInitContainers.prepareWriteDirs.containerSecurityContext.capabilities "context" .) | nindent 6 }}
    {{- end }}
  {{- end }}
  {{- if .Values.defaultInitContainers.prepareWriteDirs.resources }}
  resources: {{- toYaml .Values.defaultInitContainers.prepareWriteDirs.resources | nindent 4 }}
  {{- end }}
  command:
    - /bin/sh
  args:
    - -ec
    - |
      echo "Copying writable dirs to empty dir"
      # In order to not break the application functionality we need to make some
      # directories writable, so we need to copy it to an empty dir volume
      mkdir -p /emptydir/app-conf-dir && cp -r /opt/keycloak/conf/. /emptydir/app-conf-dir/
      cp -r /opt/keycloak/lib/quarkus /emptydir/app-quarkus-dir
      cp -r /opt/keycloak/data /emptydir/app-data-dir
      cp -r /opt/keycloak/providers /emptydir/app-providers-dir
      cp -r /opt/keycloak/themes /emptydir/app-themes-dir
      {{- if and (eq (include "keycloak.replicaKind" .) "Deployment") .Values.cache.remote.host (not .Values.cache.configFile) }}
      # Copy custom cache configuration file after conf directory
      echo "Copying custom cache configuration file"
      cp /cache-config/cache-ispn-full-remote.xml /emptydir/app-conf-dir/cache-ispn-full-remote.xml
      echo "Cache config file copied successfully"
      {{- end }}
  volumeMounts:
   - name: empty-dir
     mountPath: /emptydir
  {{- if and (eq (include "keycloak.replicaKind" .) "Deployment") .Values.cache.remote.host (not .Values.cache.configFile) }}
   - name: full-remote-cache-config
     mountPath: /cache-config
  {{- end }}
{{- end -}}
