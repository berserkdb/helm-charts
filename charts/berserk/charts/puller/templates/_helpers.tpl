{{- define "puller.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "puller.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "puller.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "puller.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "puller.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "puller.image" -}}{{ include "berserk-common.image" . }}{{- end }}
