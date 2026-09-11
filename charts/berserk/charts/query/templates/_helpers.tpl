{{- define "query.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "query.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "query.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "query.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "query.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "query.image" -}}{{ include "berserk-common.image" . }}{{- end }}

{{/*
Query admission cap. Admission is a memory budget, not a query count: take
`config.queryAdmissionBudgetFraction` of the container memory limit and divide
by the assumed per-query footprint. `config.maxConcurrentQueries` overrides the
derivation outright. Fails loudly rather than guessing — a wrong cap here is an
OOMKill, not a slow query.
*/}}
{{- define "query.memoryLimitMi" -}}
{{- $q := . | toString -}}
{{- if hasSuffix "Gi" $q -}}
{{- mulf (trimSuffix "Gi" $q) 1024 | int64 -}}
{{- else if hasSuffix "Mi" $q -}}
{{- trimSuffix "Mi" $q | int64 -}}
{{- else -}}
{{- fail (printf "query chart: cannot derive max_concurrent_queries from resources.limits.memory=%q — use Mi or Gi, or set config.maxConcurrentQueries explicitly" $q) -}}
{{- end -}}
{{- end -}}

{{- define "query.maxConcurrentQueries" -}}
{{- if hasKey .Values.config "maxConcurrentQueries" -}}
{{- .Values.config.maxConcurrentQueries -}}
{{- else -}}
{{- $limit := (.Values.resources.limits).memory -}}
{{- if not $limit -}}
{{- fail "query chart: resources.limits.memory is unset, so max_concurrent_queries cannot be derived — set config.maxConcurrentQueries explicitly" -}}
{{- end -}}
{{- $budget := mulf (include "query.memoryLimitMi" $limit) .Values.config.queryAdmissionBudgetFraction -}}
{{- max 1 (div ($budget | int64) (.Values.config.queryBaseSizeMi | int64)) -}}
{{- end -}}
{{- end -}}
