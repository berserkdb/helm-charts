{{/*
Deployment header: everything from apiVersion through imagePullSecrets.
The calling template continues with the containers: list.
*/}}
{{- define "berserk-common.deployment.header" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "berserk-common.fullname" . }}
  labels:
    {{- include "berserk-common.labels" . | nindent 4 }}
    component: {{ .Values.component | default "backend" }}
spec:
  {{- /* With autoscaling the HPA owns the scale — emitting replicas here would
        reset it on every helm/ArgoCD sync. */}}
  {{- if not ((.Values.autoscaling | default dict).enabled) }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  revisionHistoryLimit: {{ .Values.revisionHistoryLimit | default 2 }}
  {{- with .Values.strategy }}
  strategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "berserk-common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "berserk-common.selectorLabels" . | nindent 8 }}
        component: {{ .Values.component | default "backend" }}
      {{- with .Values.podAnnotations }}
      annotations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
    spec:
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
{{- include "berserk-common.scheduling" . }}
{{- end }}

{{/*
Node scheduling constraints: nodeSelector, tolerations, affinity.
Per-service values override global defaults.
Usage: {{ include "berserk-common.scheduling" . }}
*/}}
{{- define "berserk-common.scheduling" -}}
      {{- with (.Values.nodeSelector | default .Values.global.nodeSelector) }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (.Values.tolerations | default .Values.global.tolerations) }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with (.Values.affinity | default .Values.global.affinity) }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}

{{/*
ServiceAccount for the pod: `global.serviceAccountName`, else the namespace's `default`.
Always named: a pod spec that drops the field keeps the old name through the deprecated
`serviceAccount` field, so its new pods would ask for an account the chart has deleted.
Usage: {{ include "berserk-common.serviceAccountName" . }}
*/}}
{{- define "berserk-common.serviceAccountName" }}
      serviceAccountName: {{ .Values.global.serviceAccountName | default "default" }}
{{- end }}

{{/*
S3 credentials env vars from secret.
Usage: {{ include "berserk-common.env.s3-credentials" (dict "accessKeyEnv" "AWS_ACCESS_KEY_ID" "secretKeyEnv" "AWS_SECRET_ACCESS_KEY" "Values" .Values) }}
*/}}
{{- define "berserk-common.env.s3-credentials" -}}
- name: {{ .accessKeyEnv }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.s3Credentials.secretName }}
      key: {{ .Values.global.s3Credentials.accessKeyIdKey }}
      optional: true
- name: {{ .secretKeyEnv }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.s3Credentials.secretName }}
      key: {{ .Values.global.s3Credentials.secretAccessKeyKey }}
      optional: true
{{- end }}

{{/*
Master key env vars (docs/dev/master-key.md). The secondary key is optional:
present only while a rotation is staged.
Usage: {{ include "berserk-common.env.master-key" . | nindent 12 }}
*/}}
{{- define "berserk-common.env.master-key" -}}
- name: BZRK_MASTER_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.masterKey.secretName }}
      key: {{ .Values.global.masterKey.key }}
- name: BZRK_SECONDARY_MASTER_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.masterKey.secretName }}
      key: {{ .Values.global.masterKey.secondaryKey }}
      optional: true
{{- if ne (int .Values.global.masterKey.minLength) 32 }}
- name: BZRK_MASTER_KEY_MIN_LENGTH
  value: {{ .Values.global.masterKey.minLength | quote }}
{{- end }}
{{- end }}

{{/*
License keys (docs/dev/licensing.md). Meta reads META_LICENSE_KEYS, a JSON array of
key strings, at startup. Keys are not secret, so the default renders them inline; set
`global.license.existingSecret` to read them from a Secret instead.
Usage: {{ include "berserk-common.env.license" . | nindent 12 }}
*/}}
{{- define "berserk-common.env.license" -}}
{{- $license := .Values.global.license | default dict }}
{{- if $license.existingSecret }}
- name: META_LICENSE_KEYS
  valueFrom:
    secretKeyRef:
      name: {{ $license.existingSecret }}
      key: {{ $license.existingSecretKey | default "license_keys" }}
{{- else if $license.keys }}
- name: META_LICENSE_KEYS
  value: {{ toJson $license.keys | quote }}
{{- end }}
{{- end }}

{{/*
Telemetry resource attributes — stamps `bzrk.cluster.name`, `service.namespace`
and the standard k8s.{pod,namespace,node}.name via OTEL_RESOURCE_ATTRIBUTES,
which the Rust SDK merges into every exported record.

`service.namespace` groups this install's service names, so a catalog holding
both Berserk's own services and the applications it observes can tell them
apart. It belongs here rather than in the Rust resource builder for two
reasons: the SDK applies programmatic attributes *over* the env detector, so a
value set in code could not be overridden by an operator; and grouping is a
deployment decision, which is what everything else in this variable is.

`bzrk.cluster.name` is Berserk-specific (not an OTel semantic convention)
because a "Berserk cluster" is a Helm install / logical tenant, not a
Kubernetes cluster — multiple Berserk clusters can share one k8s cluster.
Used to distinguish Berserk installs in alerts/queries, especially when
services ship telemetry across cluster boundaries and bypass any
k8sattributes-enriching collector.

The k8s.* attrs come from the downward API. Kubelet expands $(POD_NAME) /
$(POD_NAMESPACE) / $(NODE_NAME) inside subsequent env values, so apps don't
need any SDK-side k8s detector. This lets services preserve k8s.pod.name /
k8s.namespace.name / k8s.node.name on self-telemetry that goes straight to
the ingest service without traversing an upstream k8sattributes processor
(notably the EKS deployment, which has no in-cluster otel-collector).

Usage: {{ include "berserk-common.env.cluster-name" . | nindent 12 }}
*/}}
{{- define "berserk-common.env.cluster-name" -}}
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
- name: OTEL_RESOURCE_ATTRIBUTES
  value: "bzrk.cluster.name={{ .Values.global.clusterName | default "default" }}{{ with .Values.global.serviceNamespace }},service.namespace={{ . }}{{ end }},k8s.pod.name=$(POD_NAME),k8s.namespace.name=$(POD_NAMESPACE),k8s.node.name=$(NODE_NAME)"
{{- include "berserk-common.env.otlp-remote" . }}
{{- include "berserk-common.env.otlp-system-token" . }}
{{- end }}

{{/*
Whether a service's own telemetry carries the system ingest token to its OTLP
endpoint (global.observability.systemToken). By default only when the endpoint
is this install's own ingest, by its short or namespaced service name, so the
token never reaches another collector.
*/}}
{{- define "berserk-common.env.otlp-system-token" -}}
{{- $obs := .Values.global.observability }}
{{- $endpoint := ((.Values.config | default dict).observability | default dict).otlpEndpoint | default $obs.otlpEndpoint | trimPrefix "http://" | trimPrefix "https://" | trimSuffix "/" }}
{{- $ingest := printf "^ingest(\\.%s(\\.svc(\\.cluster\\.local)?)?)?:4317$" (regexQuoteMeta .Release.Namespace) }}
{{- $on := ternary $obs.systemToken (regexMatch $ingest $endpoint) (hasKey $obs "systemToken") }}
- name: BZRK_OTLP_SYSTEM_TOKEN
  value: {{ ternary "true" "false" (eq (toString $on) "true") | quote }}
{{- end }}

{{/*
The second telemetry destination (global.observability.remote), which every
service and the children it relays for ship to beside this install's ingest.
*/}}
{{- define "berserk-common.env.otlp-remote" -}}
{{- $remote := .Values.global.observability.remote | default dict }}
{{- $secret := $remote.tokenSecret | default dict }}
{{- if and $secret.name (eq $secret.name $.Values.global.masterKey.secretName) }}
{{- fail "global.observability.remote.tokenSecret names the master key Secret; the remote takes an ingest token its cluster issued" }}
{{- end }}
{{- if and (or $secret.name $secret.key) (not (and $secret.name $secret.key)) }}
{{- fail "global.observability.remote.tokenSecret needs both name and key, or neither" }}
{{- end }}
{{- with $remote.endpoint }}
{{- if not (or (hasPrefix "http://" .) (hasPrefix "https://" .)) }}
{{- fail (printf "global.observability.remote.endpoint %s needs an http:// or https:// scheme" .) }}
{{- end }}
- name: BZRK_OTLP_REMOTE_ENDPOINT
  value: {{ . | quote }}
{{- with $secret.name }}
- name: BZRK_OTLP_REMOTE_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ . }}
      key: {{ $secret.key }}
{{- end }}
{{- else }}
{{- if $secret.name }}
{{- fail "global.observability.remote.tokenSecret is set without global.observability.remote.endpoint" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Config volume definition.
*/}}
{{- define "berserk-common.volume.config" -}}
- name: config
  configMap:
    name: {{ include "berserk-common.configName" . }}
{{- end }}

{{/*
Config volume mount.
*/}}
{{- define "berserk-common.volumeMount.config" -}}
- name: config
  mountPath: /config
  readOnly: true
{{- end }}

{{/*
Node-identity volume, for workloads that register with meta but own no
persistent storage to keep an identity in.

An emptyDir, so the id survives a container restart within the pod — a crash
loop re-registers the same record instead of leaving a ghost behind for each
attempt — and is fresh for every new pod, which is what a new pod is. Workloads
that already have a directory of their own (query, nursery, janitor) derive
their id from that instead and do not mount this.

Sized for a 36-byte UUID and the temp file it is renamed from.

Usage: {{ include "berserk-common.volume.node-id" . | nindent 8 }}
*/}}
{{- define "berserk-common.volume.node-id" -}}
- name: node-id
  emptyDir:
    sizeLimit: 1Mi
{{- end }}

{{/*
Node-identity volume mount. The path is a directory; the file inside it is
named by the process.
*/}}
{{- define "berserk-common.volumeMount.node-id" -}}
- name: node-id
  mountPath: /var/lib/bzrk/node-id
{{- end }}

{{/*
Where to keep the node identity. One shared name rather than a per-service
config key: the value is the same everywhere, and it is read by shared
registration code rather than by any one service's config.
*/}}
{{- define "berserk-common.env.node-id" -}}
- name: BZRK_NODE_ID_DIR
  value: /var/lib/bzrk/node-id
{{- end }}

{{/*
Object-store connection-pool socket settings, for the services that open S3 pools.

Properties of the ENDPOINT rather than of any one service, so they live under
global.storage and are rendered identically onto every workload that opens a pool.
Shared here rather than copied per workload: four copies of the emptiness test is
how they drift apart.

An absent or empty value renders NOTHING, which is load-bearing. Keepalive and
TCP_USER_TIMEOUT are disabled by being unset — that is their off switch, and the
shipped default — so a template that emitted a placeholder would turn on a socket
option nobody asked for. `poolIdleTimeout` unset likewise means "use the
compiled-in default".

Neither `with` nor `default` can express that test: sprig treats numeric 0 as
empty, so `poolIdleTimeout: 0` would silently vanish and the process would use its
default rather than reporting the value. Comparing the stringified form keeps "0"
— it reaches the parser, which rounds a too-small value up to the smallest the
kernel can represent and says so. A missing key stringifies to "<nil>", which is
excluded explicitly for the same reason: it is absence, not a value.

Usage: {{ include "berserk-common.env.s3-pool" . | nindent 12 }}
*/}}
{{- define "berserk-common.env.s3-pool" -}}
{{- $idle := .Values.global.storage.poolIdleTimeout | toString -}}
{{- $keepalive := .Values.global.storage.tcpKeepalive | toString -}}
{{- $userTimeout := .Values.global.storage.tcpUserTimeout | toString -}}
{{- if and (ne $idle "") (ne $idle "<nil>") }}
- name: BZRK_S3_POOL_IDLE_TIMEOUT
  value: {{ $idle | quote }}
{{- end }}
{{- if and (ne $keepalive "") (ne $keepalive "<nil>") }}
- name: BZRK_S3_TCP_KEEPALIVE
  value: {{ $keepalive | quote }}
{{- end }}
{{- if and (ne $userTimeout "") (ne $userTimeout "<nil>") }}
- name: BZRK_S3_TCP_USER_TIMEOUT
  value: {{ $userTimeout | quote }}
{{- end }}
{{- end }}

{{/*
Split debug info (docs/dev/stripped-builds-split-debuginfo.md). Release binaries ship fully
stripped; on the clusters we operate, an init-container fetches each binary's <build-id>.debug from
the password-gated symbol store and lays it under /usr/lib/debug, where blazesym (the profiler) and
std's panic backtrace resolve it unchanged. Gated on global.symbols.enabled; absent elsewhere, so
self-hosted installs run the same stripped image with no symbols.

The artifact reference is service name + the chart's imageTag — exactly what the release published —
so the symbols can never drift from the binary and no in-cluster digest resolution is needed. The CI
publish preserves the file layout, so the init-container is the stock oras image pulling straight
into /usr/lib/debug.

Fail-open on purpose: symbols are a debugging aid, so a failed fetch (registry down, credential
revoked, secret missing) logs `debug_symbols_fetch_failed` and the service starts without them —
frames resolve to hex. Revoking a consumer's credential must never stop its pods from restarting.
*/}}
{{- define "berserk-common.debuginfoRef" -}}
{{- $prefix := .Values.global.symbols.repoPrefix | default "images.bzrk.dev/debug" -}}
{{- $tag := .Values.image.tag | default .Values.global.imageTag | default (printf "v%s" .Chart.AppVersion) -}}
{{- printf "%s/%s%s:%s" $prefix .Chart.Name (.Values.global.symbols.repoSuffix | default "") $tag -}}
{{- end }}

{{- define "berserk-common.initContainer.symbols" -}}
{{- if .Values.global.symbols.enabled }}
- name: fetch-debug-symbols
  image: {{ .Values.global.symbols.fetcherImage | quote }}
  imagePullPolicy: {{ .Values.global.imagePullPolicy | default "Always" }}
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    allowPrivilegeEscalation: false
  env:
    - name: SYMBOLS_REF
      value: {{ include "berserk-common.debuginfoRef" . | quote }}
  {{- if .Values.global.symbols.registryConfigSecret }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      if oras pull --registry-config /run/debug-symbols-auth/.dockerconfigjson --output /usr/lib/debug "$SYMBOLS_REF"; then
        echo "debug symbols fetched: $SYMBOLS_REF"
      else
        echo "debug_symbols_fetch_failed ref=$SYMBOLS_REF: starting without debug symbols" >&2
      fi
  volumeMounts:
    - name: debug-symbols
      mountPath: /usr/lib/debug
    - name: debug-symbols-auth
      mountPath: /run/debug-symbols-auth
      readOnly: true
  {{- else }}
    - name: SYMBOLS_USERNAME
      value: {{ .Values.global.symbols.username | quote }}
    - name: SYMBOLS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: {{ .Values.global.symbols.passwordSecret.name | quote }}
          key: {{ .Values.global.symbols.passwordSecret.key | quote }}
          # A missing secret must not block the pod either; the pull then fails and is logged.
          optional: true
  # The password goes over stdin, never argv.
  command: ["/bin/sh", "-c"]
  args:
    - |
      if printf '%s' "$SYMBOLS_PASSWORD" | oras pull --username "$SYMBOLS_USERNAME" --password-stdin --output /usr/lib/debug "$SYMBOLS_REF"; then
        echo "debug symbols fetched: $SYMBOLS_REF"
      else
        echo "debug_symbols_fetch_failed ref=$SYMBOLS_REF user=$SYMBOLS_USERNAME: starting without debug symbols" >&2
      fi
  volumeMounts:
    - name: debug-symbols
      mountPath: /usr/lib/debug
  {{- end }}
{{- end }}
{{- end }}

{{- define "berserk-common.volume.symbols" -}}
{{- if .Values.global.symbols.enabled }}
- name: debug-symbols
  emptyDir: {}
{{- if .Values.global.symbols.registryConfigSecret }}
- name: debug-symbols-auth
  secret:
    secretName: {{ .Values.global.symbols.registryConfigSecret | quote }}
    # A missing secret must not block the pod; the pull then fails and is logged.
    optional: true
{{- end }}
{{- end }}
{{- end }}

{{- define "berserk-common.volumeMount.symbols" -}}
{{- if .Values.global.symbols.enabled }}
- name: debug-symbols
  mountPath: /usr/lib/debug
  readOnly: true
{{- end }}
{{- end }}
