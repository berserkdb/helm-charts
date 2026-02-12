{{/*
Expand the name of the chart.
*/}}
{{- define "meta.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "meta.fullname" -}}
meta-service
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "meta.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "meta.labels" -}}
helm.sh/chart: {{ include "meta.chart" . }}
{{ include "meta.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "meta.selectorLabels" -}}
app: meta
app.kubernetes.io/name: {{ include "meta.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image name
*/}}
{{- define "meta.image" -}}
{{- $registry := .Values.global.imageRegistry | default "ghcr.io/berserkdb" }}
{{- $repository := .Values.image.repository | default "meta" }}
{{- $tag := .Values.image.tag | default .Values.global.imageTag | default .Chart.AppVersion }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}
