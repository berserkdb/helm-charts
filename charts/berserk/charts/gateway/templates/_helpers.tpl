{{- define "gateway.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "gateway.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "gateway.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "gateway.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "gateway.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "gateway.image" -}}{{ include "berserk-common.image" . }}{{- end }}
