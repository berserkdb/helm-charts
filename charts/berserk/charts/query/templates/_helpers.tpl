{{- define "query.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "query.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "query.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "query.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "query.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "query.image" -}}{{ include "berserk-common.image" . }}{{- end }}

{{- /* A whole-number Kubernetes quantity ("128Gi", "500G", "1073741824") in bytes. */}}
{{- define "query.quantityBytes" -}}
{{- $quantity := toString . -}}
{{- $number := regexFind "^[0-9]+" $quantity -}}
{{- $suffix := trimPrefix $number $quantity -}}
{{- $units := dict "" 1 "Ki" 1024 "Mi" 1048576 "Gi" 1073741824 "Ti" 1099511627776 "Pi" 1125899906842624 "k" 1000 "M" 1000000 "G" 1000000000 "T" 1000000000000 "P" 1000000000000000 -}}
{{- if or (not $number) (not (hasKey $units $suffix)) -}}
{{- fail (printf "%q is not a whole-number Kubernetes quantity such as 128Gi" $quantity) -}}
{{- end -}}
{{- mul (int64 $number) (index $units $suffix) -}}
{{- end }}

{{- /* Disk for cached lookup-table files on each node: config.lookupTableCacheBytes, or 5% of
      cache.size, at least 5 GiB and at most 50 GiB. Never more than half the volume. */}}
{{- define "query.lookupTableCacheBytes" -}}
{{- $total := int64 (include "query.quantityBytes" .Values.cache.size) -}}
{{- $budget := 0 -}}
{{- if .Values.config.lookupTableCacheBytes -}}
{{- $budget = int64 .Values.config.lookupTableCacheBytes -}}
{{- else -}}
{{- $budget = min (max (div (mul $total 5) 100) 5368709120) 53687091200 -}}
{{- end -}}
{{- if gt (mul $budget 2) $total -}}
{{- fail (printf "the lookup-table cache (%d bytes) is more than half of cache.size (%s); set query.config.lookupTableCacheBytes lower" $budget (toString .Values.cache.size)) -}}
{{- end -}}
{{- $budget -}}
{{- end }}

