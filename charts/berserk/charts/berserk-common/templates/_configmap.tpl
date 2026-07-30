{{/*
Content-addressed ConfigMap name: <service>-config-<hash of the data>.

A config revision is pinned to the pod template that mounts it. Changing the
config renames the ConfigMap, which changes the pod template and rolls the pods;
a pod that is already running keeps the exact revision it booted with, instead of
kubelet swapping a newer one in underneath a container that cannot parse it.
Rollback works for the same reason: the previous ReplicaSet still names the
previous ConfigMap.
*/}}
{{- define "berserk-common.configName" -}}
{{- $hash := include (printf "%s.config-data" .Chart.Name) . | sha256sum | trunc 10 -}}
{{- printf "%s-config-%s" (include "berserk-common.fullname" .) $hash -}}
{{- end }}

{{/*
ConfigMap for a service. The consuming chart supplies the whole `data:` section
as a template named `<chart name>.config-data`.
*/}}
{{- define "berserk-common.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "berserk-common.configName" . }}
  labels:
    {{- include "berserk-common.labels" . | nindent 4 }}
{{- /* Nothing ever edits a revision in place — a change lands under a new name. */}}
immutable: true
{{ include (printf "%s.config-data" .Chart.Name) . }}
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
{{- if .Values.config.observability.profilerSampleHz }}
  profiler_sample_hz: {{ .Values.config.observability.profilerSampleHz }}
{{- end }}
{{- end }}
