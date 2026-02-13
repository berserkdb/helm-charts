{{- define "meta.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "meta.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "meta.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "meta.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "meta.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "meta.image" -}}{{ include "berserk-common.image" . }}{{- end }}
