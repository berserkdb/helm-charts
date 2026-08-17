{{- define "ui.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "ui.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "ui.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "ui.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "ui.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "ui.image" -}}{{ include "berserk-common.image" . }}{{- end }}

{{/* Where the collector gets its scrape targets: kubernetes | static | meta.

     `collector.discovery` names it outright. Left empty it derives from the
     older `collector.podDiscovery` boolean, so an install that predates the
     third mode keeps rendering exactly what it rendered before. */}}
{{- define "ui.collectorDiscovery" -}}
{{- $c := .Values.collector | default dict -}}
{{- $explicit := $c.discovery | default "" -}}
{{- if $explicit -}}
{{-   if not (has $explicit (list "kubernetes" "static" "meta")) -}}
{{-     fail (printf "ui: collector.discovery must be one of kubernetes|static|meta, got %q" $explicit) -}}
{{-   end -}}
{{-   $explicit -}}
{{- else -}}
{{-   ternary "kubernetes" "static" ($c.podDiscovery | default false) -}}
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
     handing out access nothing uses. */}}
{{- define "ui.podDiscoveryRBAC" -}}
{{- $c := .Values.collector | default dict -}}
{{- $usesKubeApi := eq (include "ui.collectorDiscovery" .) "kubernetes" -}}
{{- and $c.enabled $usesKubeApi $c.rbac | ternary "true" "" -}}
{{- end -}}
