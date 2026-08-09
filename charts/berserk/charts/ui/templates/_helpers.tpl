{{- define "ui.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "ui.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "ui.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "ui.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "ui.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "ui.image" -}}{{ include "berserk-common.image" . }}{{- end }}

{{/* "true" when the chart should own the operator-metrics collector's pod-discovery
     ServiceAccount + Role. Three separate switches because they have distinct
     reasons: the feature off, discovery off but the collector on with static
     targets, or bring-your-own RBAC. */}}
{{- define "ui.podDiscoveryRBAC" -}}
{{- $c := .Values.collector | default dict -}}
{{- and $c.enabled $c.podDiscovery $c.rbac | ternary "true" "" -}}
{{- end -}}
