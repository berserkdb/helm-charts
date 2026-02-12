{{/*
Expand the name of the chart.
*/}}
{{- define "nursery.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "nursery.fullname" -}}
nursery
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "nursery.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "nursery.labels" -}}
helm.sh/chart: {{ include "nursery.chart" . }}
{{ include "nursery.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "nursery.selectorLabels" -}}
app: nursery
app.kubernetes.io/name: {{ include "nursery.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Image name
*/}}
{{- define "nursery.image" -}}
{{- $registry := .Values.global.imageRegistry | default "ghcr.io/berserkdb" }}
{{- $repository := .Values.image.repository | default "nursery" }}
{{- $tag := .Values.image.tag | default .Values.global.imageTag | default .Chart.AppVersion }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- end }}
