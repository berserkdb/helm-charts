{{/*
Expand the name of the chart.
*/}}
{{- define "berserk-common.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
For subcharts, .Chart.Name equals the subchart name (e.g., "meta", "query").
*/}}
{{- define "berserk-common.fullname" -}}
{{- .Chart.Name }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "berserk-common.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "berserk-common.labels" -}}
helm.sh/chart: {{ include "berserk-common.chart" . }}
{{ include "berserk-common.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.Version | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "berserk-common.selectorLabels" -}}
app: {{ .Chart.Name }}
app.kubernetes.io/name: {{ include "berserk-common.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image name
*/}}
{{- define "berserk-common.image" -}}
{{- $registry := .Values.global.imageRegistry | default "ghcr.io/berserkdb" }}
{{- $repository := .Values.image.repository | default .Chart.Name }}
{{- $tag := .Values.image.tag | default .Values.global.imageTag | default .Chart.Version }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}
