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
Common observability config block for config.yaml data. Both telemetry
destinations render from berserk-common.otlp-destinations; the remote's token is
substituted at load from BZRK_OTLP_REMOTE_TOKEN, which
berserk-common.env.otlp-remote-token sets from its Secret.
Include with appropriate nindent inside the config.yaml data section.
*/}}
{{- define "berserk-common.observability-config" -}}
{{- $obs := .Values.config.observability -}}
{{- $d := include "berserk-common.otlp-destinations" . | fromYaml -}}
{{/* The `hasKey` rule of berserk-common.otlp-destinations. Rendered only when off: the binaries
     default to on, and a config that names the key is rejected by any image
     older than it, so the default must not depend on every service having
     been rebuilt. */}}
{{- $profilerEnabled := ternary (index $obs "profilerEnabled") (index .Values.global.observability "profilerEnabled") (hasKey $obs "profilerEnabled") -}}
observability:
  service_name: {{ .Values.config.observability.serviceName | quote }}
  log_level: {{ .Values.config.observability.logLevel | quote }}
  otlp_enabled: {{ $d.localEnabled }}
  otlp_endpoint: {{ $d.localEndpoint | quote }}
  system_token: {{ $d.systemToken }}
{{- with $d.remoteEndpoint }}
  remote:
    endpoint: {{ . | quote }}
{{- if $d.remoteTokenSecret.name }}
    token: "${BZRK_OTLP_REMOTE_TOKEN:}"
{{- end }}
{{- end }}
{{- if eq $profilerEnabled false }}
  profiler_enabled: false
{{- end }}
{{- if .Values.config.observability.profilerSampleHz }}
  profiler_sample_hz: {{ .Values.config.observability.profilerSampleHz }}
{{- end }}
{{- end }}
