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
  replicas: {{ .Values.replicaCount }}
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
ServiceAccount name from global config.
Usage: {{ include "berserk-common.serviceAccountName" . }}
*/}}
{{- define "berserk-common.serviceAccountName" -}}
{{- with .Values.global.serviceAccountName }}
      serviceAccountName: {{ . }}
{{- end }}
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
Telemetry resource attributes — stamps `bzrk.cluster.name` plus the standard
k8s.{pod,namespace,node}.name via OTEL_RESOURCE_ATTRIBUTES, which the Rust
SDK merges into every exported record.

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
  value: "bzrk.cluster.name={{ .Values.global.clusterName | default "default" }},k8s.pod.name=$(POD_NAME),k8s.namespace.name=$(POD_NAMESPACE),k8s.node.name=$(NODE_NAME)"
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
