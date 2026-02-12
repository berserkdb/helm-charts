{{/*
Expand the name of the chart.
*/}}
{{- define "query.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "query.fullname" -}}
query
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "query.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "query.labels" -}}
helm.sh/chart: {{ include "query.chart" . }}
{{ include "query.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "query.selectorLabels" -}}
app: query
app.kubernetes.io/name: {{ include "query.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image name
*/}}
{{- define "query.image" -}}
{{- $registry := .Values.global.imageRegistry | default "ghcr.io/berserkdb" }}
{{- $repository := .Values.image.repository | default "query" }}
{{- $tag := .Values.image.tag | default .Values.global.imageTag | default .Chart.AppVersion }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}
