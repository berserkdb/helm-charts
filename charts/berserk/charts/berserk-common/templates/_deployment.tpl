{{/*
Deployment header: everything from apiVersion through imagePullSecrets.
The calling template continues with the containers: list.
Uses $.Template.BasePath from the calling chart's context for configmap checksum.
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
  selector:
    matchLabels:
      {{- include "berserk-common.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "berserk-common.selectorLabels" . | nindent 8 }}
        component: {{ .Values.component | default "backend" }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      {{- with .Values.global.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
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
- name: {{ .secretKeyEnv }}
  valueFrom:
    secretKeyRef:
      name: {{ .Values.global.s3Credentials.secretName }}
      key: {{ .Values.global.s3Credentials.secretAccessKeyKey }}
{{- end }}

{{/*
Config volume definition.
*/}}
{{- define "berserk-common.volume.config" -}}
- name: config
  configMap:
    name: {{ include "berserk-common.fullname" . }}-config
{{- end }}

{{/*
Config volume mount.
*/}}
{{- define "berserk-common.volumeMount.config" -}}
- name: config
  mountPath: /config
  readOnly: true
{{- end }}
