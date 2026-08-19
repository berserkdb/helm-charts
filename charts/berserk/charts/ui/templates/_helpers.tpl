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

{{/* "true" when the chart should own ui's ServiceAccount.

     Identity, NOT permission — deliberately not gated on the discovery mode.
     The pod names this account, so making its existence conditional on a
     permission it happens to need would delete the account out from under a
     running Deployment the moment that permission stopped being needed, and
     every subsequent pod would fail to schedule with `serviceaccount not
     found`. Which is exactly what switching to `discovery: meta` did before
     this was split in two. */}}
{{- define "ui.ownServiceAccount" -}}
{{- $c := .Values.collector | default dict -}}
{{- and $c.enabled $c.rbac (not .Values.global.serviceAccountName) | ternary "true" "" -}}
{{- end -}}

{{/* "true" when that account should also be allowed to list pods. This is the
     permission half, and it IS gated on the discovery mode: a collector reading
     the fleet registry never calls the Kubernetes API, so granting it would be
     handing out access nothing uses. `union` reads both sources, so it needs the
     role exactly as `kubernetes` does. */}}
{{- define "ui.podDiscoveryRBAC" -}}
{{- $c := .Values.collector | default dict -}}
{{- $usesKubeApi := has (include "ui.collectorDiscovery" .) (list "kubernetes" "union") -}}
{{- and $c.enabled $usesKubeApi $c.rbac | ternary "true" "" -}}
{{- end -}}
