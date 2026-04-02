{{/*
Copyright 2020-2026 Broadcom, Inc. All Rights Reserved.
Copyright 2026 Mathieu CARBONNEAUX
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/*
Return the proper Keycloak image name
*/}}
{{- define "keycloak.image" -}}
{{- $registryName := .Values.image.registry -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | toString -}}
{{- if $registryName -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else -}}
    {{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{- define "keycloak.keycloakConfigCli.image" -}}
{{- $registryName := .Values.keycloakConfigCli.image.registry -}}
{{- $repositoryName := .Values.keycloakConfigCli.image.repository -}}
{{- $tag := .Values.keycloakConfigCli.image.tag | toString -}}
{{- if $registryName -}}
    {{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else -}}
    {{- printf "%s:%s" $repositoryName $tag -}}
{{- end -}}
{{- end -}}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "keycloak.imagePullSecrets" -}}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "common.names.name" -}}
{{- $name := "keycloak" -}}
{{- if . -}}
  {{- if and (typeIs "dict" .) (hasKey . "Chart") -}}
    {{- $name = .Chart.Name -}}
  {{- end -}}
  {{- if and (typeIs "dict" .) (hasKey . "Values") -}}
    {{- if .Values.nameOverride -}}
      {{- $name = .Values.nameOverride -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name
*/}}
{{- define "common.names.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "common.labels.standard" -}}
{{- $context := . -}}
{{- $customLabels := dict -}}
{{- if and (typeIs "dict" .) (hasKey . "context") -}}
  {{- $context = .context -}}
{{- end -}}
{{- if and (typeIs "dict" .) (hasKey . "customLabels") -}}
  {{- if typeIs "string" .customLabels -}}
    {{- $customLabels = fromYaml .customLabels -}}
  {{- else -}}
    {{- $customLabels = .customLabels -}}
  {{- end -}}
{{- end -}}
{{- if $context -}}
{{- if not (and $customLabels (hasKey $customLabels "app.kubernetes.io/name")) }}
app.kubernetes.io/name: {{ include "common.names.name" $context }}
{{- end }}
{{- if $context.Release }}
{{- if not (and $customLabels (hasKey $customLabels "app.kubernetes.io/instance")) }}
app.kubernetes.io/instance: {{ $context.Release.Name | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ $context.Release.Service | quote }}
{{- end }}
{{- if and $context.Chart $context.Chart.AppVersion }}
app.kubernetes.io/version: {{ $context.Chart.AppVersion | quote }}
{{- end }}
{{- if and $context.Values $context.Values.commonLabels }}
{{- range $key, $val := $context.Values.commonLabels }}
{{- if and (ne $key "app.kubernetes.io/name") (ne $key "app.kubernetes.io/instance") (ne $key "app.kubernetes.io/managed-by") (ne $key "app.kubernetes.io/version") }}
{{ $key }}: {{ $val | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- if $customLabels }}
{{- range $key, $val := $customLabels }}
{{- if and (ne $key "app.kubernetes.io/managed-by") (ne $key "app.kubernetes.io/version") (ne $key "app.kubernetes.io/name") (ne $key "app.kubernetes.io/instance") }}
{{ $key }}: {{ $val | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "common.labels.matchLabels" -}}
{{- $context := . -}}
{{- $customLabels := dict -}}
{{- if and (typeIs "dict" .) (hasKey . "context") -}}
  {{- $context = .context -}}
{{- end -}}
{{- if and (typeIs "dict" .) (hasKey . "customLabels") -}}
  {{- if typeIs "string" .customLabels -}}
    {{- $customLabels = fromYaml .customLabels -}}
  {{- else -}}
    {{- $customLabels = .customLabels -}}
  {{- end -}}
{{- end -}}
{{- if $context -}}
{{- if and (not (and $customLabels (hasKey $customLabels "app.kubernetes.io/name"))) (or (not (hasKey (default (dict) $context.Values) "includeNameInSelector")) $context.Values.includeNameInSelector) }}
app.kubernetes.io/name: {{ include "common.names.name" $context }}
{{- end }}
{{- if $context.Release }}
{{- if and (not (and $customLabels (hasKey $customLabels "app.kubernetes.io/instance"))) (or (not (hasKey (default (dict) $context.Values) "includeInstanceInSelector")) $context.Values.includeInstanceInSelector) }}
app.kubernetes.io/instance: {{ $context.Release.Name | quote }}
{{- end }}
{{- end }}
{{- if and $context.Values (hasKey $context.Values "includeCommonLabelsInSelector") $context.Values.includeCommonLabelsInSelector }}
{{- if $context.Values.commonLabels }}
{{- range $key, $val := $context.Values.commonLabels }}
{{- if and (ne $key "app.kubernetes.io/name") (ne $key "app.kubernetes.io/instance") (ne $key "app.kubernetes.io/managed-by") (ne $key "app.kubernetes.io/version") }}
{{ $key }}: {{ $val | quote }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- if $customLabels }}
{{- range $key, $val := $customLabels }}
{{ $key }}: {{ $val | quote }}
{{- end }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Selector labels for Pods (must include selector labels + others if needed)
*/}}
{{- define "common.labels.podLabels" -}}
{{- include "common.labels.matchLabels" . -}}
{{- end -}}

{{/*
Return the proper namespace name
*/}}
{{- define "common.names.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{/*
Renders a value that contains template.
Usage:
{{ include "common.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "common.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{/*
Merge and render a list of values that contains template.
Usage:
{{ include "common.tplvalues.merge" ( dict "values" (list .Values.path.to.the.Value1 .Values.path.to.the.Value2) "context" $) }}
*/}}
{{- define "common.tplvalues.merge" -}}
    {{- $dst := dict -}}
    {{- range .values -}}
        {{- if . -}}
            {{- if typeIs "string" . -}}
                {{- $src := fromYaml (tpl . $.context) -}}
                {{- if $src -}}
                    {{- $dst = merge $dst $src -}}
                {{- end -}}
            {{- else -}}
                {{- $src := fromYaml (tpl (. | toYaml) $.context) -}}
                {{- if $src -}}
                    {{- $dst = merge $dst $src -}}
                {{- end -}}
            {{- end -}}
        {{- end -}}
    {{- end -}}
    {{- $dst | toYaml -}}
{{- end -}}

{{/*
Return the appropriate apiKind for keycloak (StatefulSet or Deployment).
*/}}
{{- define "keycloak.replicaKind" -}}
{{- default "StatefulSet" .Values.replicaKind -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for statefulset/deployment.
*/}}
{{- define "keycloak.workload.apiVersion" -}}
{{- print "apps/v1" -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for networkPolicy.
*/}}
{{- define "common.capabilities.networkPolicy.apiVersion" -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for HPA.
*/}}
{{- define "common.capabilities.hpa.apiVersion" -}}
{{- if semverCompare "<1.23-0" .context.Capabilities.KubeVersion.Version -}}
{{- print "autoscaling/v2beta2" -}}
{{- else -}}
{{- print "autoscaling/v2" -}}
{{- end -}}
{{- end -}}

{{/*
Manage passwords
*/}}
{{- define "common.secrets.passwords.manage" -}}
{{- $providedValue := index .providedValues 0 -}}
{{- $val := "" -}}
{{- if .context.Values -}}
  {{- $parts := splitList "." $providedValue -}}
  {{- $val = .context.Values -}}
  {{- range $parts -}}
    {{- if $val -}}
      {{- $val = index $val . -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- if $val -}}
  {{- $val | b64enc -}}
{{- else -}}
  {{- randAlphaNum 10 | b64enc -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified headless service name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "keycloak.headless.serviceName" -}}
{{- printf "%s-headless" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified headless service name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "keycloak.headless.ispn.serviceName" -}}
{{- printf "%s-headless-ispn-%s" (include "common.names.fullname" .) (replace "." "-" .Chart.AppVersion) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "keycloak.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
    {{ default (include "common.names.fullname" .) .Values.serviceAccount.name }}
{{- else -}}
    {{ default "default" .Values.serviceAccount.name }}
{{- end -}}
{{- end -}}

{{/*
Return the Keycloak configuration ConfigMap name.
*/}}
{{- define "keycloak.configmapName" -}}
{{- if .Values.existingConfigmap -}}
    {{- tpl .Values.existingConfigmap . -}}
{{- else -}}
    {{- printf "%s-configuration" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret containing the Keycloak admin password
*/}}
{{- define "keycloak.secretName" -}}
{{- if and .Values.auth .Values.auth.existingSecret -}}
    {{- tpl .Values.auth.existingSecret . -}}
{{- else -}}
    {{- include "common.names.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret key that contains the Keycloak admin password
*/}}
{{- define "keycloak.secretKey" -}}
{{- if and .Values.auth .Values.auth.existingSecret .Values.auth.passwordSecretKey -}}
    {{- tpl .Values.auth.passwordSecretKey . -}}
{{- else -}}
    {{- print "admin-password" -}}
{{- end -}}
{{- end -}}

{{/*
Return the keycloak-config-cli configuration ConfigMap name.
*/}}
{{- define "keycloak.keycloakConfigCli.configmapName" -}}
{{- if .Values.keycloakConfigCli.existingConfigmap -}}
    {{- tpl .Values.keycloakConfigCli.existingConfigmap . -}}
{{- else -}}
    {{- printf "%s-keycloak-config-cli-configmap" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database hostname
*/}}
{{- define "keycloak.database.host" -}}
{{- tpl .Values.dbHost . -}}
{{- end -}}

{{/*
Return the Database port
*/}}
{{- define "keycloak.database.port" -}}
{{- .Values.dbPort -}}
{{- end -}}

{{/*
Return the Database database name
*/}}
{{- define "keycloak.database.name" -}}
{{- tpl .Values.dbDatabase . -}}
{{- end -}}

{{/*
Return the Database user
*/}}
{{- define "keycloak.database.user" -}}
{{- tpl .Values.dbUser . -}}
{{- end -}}

{{/*
Return the Database schema
*/}}
{{- define "keycloak.database.schema" -}}
{{- .Values.dbSchema -}}
{{- end -}}

{{/*
Return extra connection parameters for the Database DSN
*/}}
{{- define "keycloak.database.extraParams" -}}
{{- if .Values.dbExtraParams -}}
    {{- printf "&%s" (tpl .Values.dbExtraParams .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database secret name
*/}}
{{- define "keycloak.database.secretName" -}}
{{- if not (empty .Values.dbExistingSecret) -}}
    {{- tpl .Values.dbExistingSecret . -}}
{{- else -}}
    {{- printf "%s-db" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Database secret key that contains the database user
*/}}
{{- define "keycloak.database.secretUserKey" -}}
{{- default "db-user" .Values.dbExistingSecretUserKey -}}
{{- end -}}

{{/*
Return the Database secret key that contains the database password
*/}}
{{- define "keycloak.database.secretPasswordKey" -}}
{{- if .Values.dbExistingSecret -}}
    {{- default "db-password" .Values.dbExistingSecretPasswordKey -}}
{{- else -}}
    {{- print "db-password" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Keycloak initdb scripts ConfigMap name.
*/}}
{{- define "keycloak.initdbScripts.configmapName" -}}
{{- if .Values.initdbScriptsConfigMap -}}
    {{- tpl .Values.initdbScriptsConfigMap . -}}
{{- else -}}
    {{- printf "%s-init-scripts" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret containing Keycloak HTTPS/TLS certificates
*/}}
{{- define "keycloak.tls.secretName" -}}
{{- if .Values.tls.existingSecret -}}
    {{- tpl .Values.tls.existingSecret . -}}
{{- else -}}
    {{- printf "%s-crt" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret containing Keycloak HTTPS/TLS keystore and truststore passwords
*/}}
{{- define "keycloak.tls.passwordsSecretName" -}}
{{- if .Values.tls.passwordsSecret -}}
    {{- tpl .Values.tls.passwordsSecret . -}}
{{- else -}}
    {{- printf "%s-tls-passwords" (include "common.names.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Compile all warnings into a single message.
*/}}
{{- define "keycloak.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "keycloak.validateValues.database" .) -}}
{{- $messages = append $messages (include "keycloak.validateValues.tls" .) -}}
{{- $messages = append $messages (include "keycloak.validateValues.production" .) -}}
{{- $messages = without $messages "" -}}
{{- $message := join "\n" $messages -}}

{{- if $message -}}
{{-   printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

{{/* Validate values of Keycloak - database */}}
{{- define "keycloak.validateValues.database" -}}
{{- if not .Values.dbHost -}}
keycloak: database
    You must specify a database host (--set dbHost=FOO).
{{- end -}}
{{- end -}}

{{/* Validate values of Keycloak - TLS enabled */}}
{{- define "keycloak.validateValues.tls" -}}
{{- if and .Values.tls.enabled (not .Values.tls.autoGenerated.enabled) (not .Values.tls.existingSecret) }}
keycloak: tls.enabled
    In order to enable TLS, you need to provide a secret with the TLS
    certificates (--set tls.existingSecret=FOO) or enable auto-generated
    TLS certificates (--set tls.autoGenerated.enabled=true).
{{- end -}}
{{- end -}}

{{/* Validate values of Keycloak - Production mode enabled */}}
{{- define "keycloak.validateValues.production" -}}
{{- if and .Values.production (not .Values.tls.enabled) (empty .Values.proxyHeaders) -}}
keycloak: production
    In order to enable Production mode, you also need to enable
    HTTPS/TLS (--set tls.enabled=true) or use proxy headers (--set proxyHeaders=FOO).
{{- end -}}
{{- end -}}

{{/*
Return the Keycloak remote cache secret name
*/}}
{{- define "keycloak.cache.remote.secretName" -}}
{{- if .Values.cache.remote.existingSecret -}}
    {{- tpl .Values.cache.remote.existingSecret . -}}
{{- else -}}
    {{- printf "%s-remote-cache" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Return the Keycloak remote cache secret key
*/}}
{{- define "keycloak.cache.remote.secretKey" -}}
{{- if .Values.cache.remote.existingSecret -}}
    {{- default "password" .Values.cache.remote.existingSecretPasswordKey -}}
{{- else -}}
    {{- print "password" -}}
{{- end -}}
{{- end -}}

{{/*
Return the Keycloak remote cache secret username key
*/}}
{{- define "keycloak.cache.remote.secretUsernameKey" -}}
{{- if .Values.cache.remote.existingSecret -}}
    {{- default "username" .Values.cache.remote.existingSecretUsernameKey -}}
{{- else -}}
    {{- print "username" -}}
{{- end -}}
{{- end -}}
