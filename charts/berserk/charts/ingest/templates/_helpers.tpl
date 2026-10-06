{{- define "ingest.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "ingest.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "ingest.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "ingest.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "ingest.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "ingest.image" -}}{{ include "berserk-common.image" . }}{{- end }}

{{/* Whether ingest presents the default token: a local `enabled` wins, even when false */}}
{{- define "ingest.tokenEnabled" -}}
{{- if hasKey .Values.config.ingestToken "enabled" -}}
{{- .Values.config.ingestToken.enabled -}}
{{- else -}}
{{- .Values.global.ingestToken.enabled -}}
{{- end -}}
{{- end -}}
