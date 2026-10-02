{{- define "meta.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "meta.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "meta.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "meta.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "meta.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "meta.image" -}}{{ include "berserk-common.image" . }}{{- end }}
{{- /* `global.vidxWrites`, `auto` when unset; anything else fails the render. */ -}}
{{- define "meta.vidxWrites" -}}
{{- $mode := .Values.global.vidxWrites | default "auto" | toString -}}
{{- if not (has $mode (list "auto" "manual")) -}}
{{- fail (printf "global.vidxWrites must be auto or manual, got %q" $mode) -}}
{{- end -}}
{{- $mode -}}
{{- end }}
