{{/*
ConfigMap metadata block. The consuming chart provides the data: section.
*/}}
{{- define "berserk-common.configmap.metadata" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "berserk-common.fullname" . }}-config
  labels:
    {{- include "berserk-common.labels" . | nindent 4 }}
{{- end }}

{{/*
Common observability config block for config.yaml data.
Renders the observability YAML block used by 5 of 6 services.
Include with appropriate nindent inside the config.yaml data section.
*/}}
{{- define "berserk-common.observability-config" -}}
{{- $otlpEnabled := .Values.config.observability.otlpEnabled | default .Values.global.observability.otlpEnabled -}}
{{- $otlpEndpoint := .Values.config.observability.otlpEndpoint | default .Values.global.observability.otlpEndpoint -}}
observability:
  service_name: {{ .Values.config.observability.serviceName | quote }}
  log_level: {{ .Values.config.observability.logLevel | quote }}
  otlp_enabled: {{ $otlpEnabled }}
  otlp_endpoint: {{ $otlpEndpoint | quote }}
{{- end }}
