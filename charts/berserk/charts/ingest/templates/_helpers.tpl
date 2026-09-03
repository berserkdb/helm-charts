{{- define "ingest.name" -}}{{ include "berserk-common.name" . }}{{- end }}
{{- define "ingest.fullname" -}}{{ include "berserk-common.fullname" . }}{{- end }}
{{- define "ingest.chart" -}}{{ include "berserk-common.chart" . }}{{- end }}
{{- define "ingest.labels" -}}{{ include "berserk-common.labels" . }}{{- end }}
{{- define "ingest.selectorLabels" -}}{{ include "berserk-common.selectorLabels" . }}{{- end }}
{{- define "ingest.image" -}}{{ include "berserk-common.image" . }}{{- end }}

{{/* Resolve ingest token config: local values override global */}}
{{- define "ingest.tokenManaged" -}}
{{- .Values.config.ingestToken.managed | default .Values.global.ingestToken.managed -}}
{{- end -}}
{{- define "ingest.tokenSecretName" -}}
{{- .Values.config.ingestToken.secretName | default .Values.global.ingestToken.secretName | default "ingest-token" -}}
{{- end -}}
{{- define "ingest.tokenKey" -}}
{{- .Values.config.ingestToken.key | default .Values.global.ingestToken.key | default "default_ingest_token" -}}
{{- end -}}
{{- define "ingest.tokenName" -}}
{{- .Values.config.ingestToken.tokenName | default .Values.global.ingestToken.tokenName | default "default_ingest_token" -}}
{{- end -}}

{{/*
CLI image for init containers (matching setup-job.yaml pattern).
Repository defaults to "cli"; override via `ingest.cliImage.repository`
(e.g. local kind installs that load `berserk/cli-dev:dev` from Bazel).
*/}}
{{- define "ingest.cliImage" -}}
{{- $registry := .Values.global.imageRegistry | default "images.bzrk.dev/release" -}}
{{- $repository := (.Values.cliImage).repository | default "cli" -}}
{{- $tag := (.Values.cliImage).tag | default .Values.global.imageTag | default (printf "v%s" .Chart.AppVersion) -}}
{{- printf "%s/%s:%s" $registry $repository $tag -}}
{{- end -}}
