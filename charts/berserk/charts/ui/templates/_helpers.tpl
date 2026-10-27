{{- define "ui.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "ui.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "ui.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "ui.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "ui.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "ui.image" -}}{{ include "berserk-common.image" . }}{{- end }}

{{/* Where the collector gets its scrape targets: meta | kubernetes | static |
     union.

     `collector.discovery` names it outright. Left empty it is the fleet
     registry, which needs nothing of the cluster — no pod-list role, no
     API-server certificate carrying the in-cluster name. `collector.podDiscovery`
     is the older boolean and still wins when set explicitly, so an install that
     asked for pod discovery before this default changed keeps getting it. */}}
{{- define "ui.collectorDiscovery" -}}
{{- $c := .Values.collector | default dict -}}
{{- $explicit := $c.discovery | default "" -}}
{{- if $explicit -}}
{{-   if not (has $explicit (list "kubernetes" "static" "meta" "union")) -}}
{{-     fail (printf "ui: collector.discovery must be one of meta|kubernetes|static|union, got %q" $explicit) -}}
{{-   end -}}
{{-   $explicit -}}
{{- else if hasKey $c "podDiscovery" -}}
{{-   ternary "kubernetes" "static" $c.podDiscovery -}}
{{- else -}}
{{-   "meta" -}}
{{- end -}}
{{- end -}}

{{/* "true" when the chart grants ui the pod-list role: the collector reads the
     Kubernetes API (`kubernetes`, or `union`, which reads both sources) and the
     chart owns the RBAC. A collector reading the fleet registry never calls the
     API, so granting it would be handing out access nothing uses. */}}
{{- define "ui.podDiscoveryRBAC" -}}
{{- $c := .Values.collector | default dict -}}
{{- $usesKubeApi := has (include "ui.collectorDiscovery" .) (list "kubernetes" "union") -}}
{{- and $c.enabled $usesKubeApi $c.rbac | ternary "true" "" -}}
{{- end -}}

{{/* "true" when the chart creates ui's own ServiceAccount: only to hold that role,
     and only when the install names no account of its own. Otherwise ui runs as
     the namespace `default` account, which the pod names explicitly
     (berserk-common.serviceAccountName), so a switch to `meta` that deletes this
     account leaves no pod naming it. */}}
{{- define "ui.ownServiceAccount" -}}
{{- and (include "ui.podDiscoveryRBAC" . | trim | eq "true") (not .Values.global.serviceAccountName) | ternary "true" "" -}}
{{- end -}}
