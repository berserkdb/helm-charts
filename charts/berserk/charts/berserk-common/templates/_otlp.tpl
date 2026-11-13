{{/*
Where a service ships its own telemetry (docs/dev/system-database.md), computed
once from global.observability and the service's config.observability, as YAML
for `fromYaml`:

  localEnabled:   the service exports to localEndpoint
  localEndpoint:  with its scheme, http:// when the value names none
  systemToken:    the local destination carries the system ingest token
  remoteEndpoint: the second destination, with its scheme; "" for none
  remoteTokenSecret: {name, key} of the remote's ingest token, or empty

The Rust services' config.yaml and the UI's environment both render from it.

`hasKey`, not `default`, for the booleans: Helm counts `false` as empty, so
`default` would let a per-service `otlpEnabled: false` inherit a global `true`.
The system token is on by default only when the endpoint is this install's own
ingest, by its short or namespaced service name, so it never reaches another
collector.
*/}}
{{- define "berserk-common.otlp-destinations" -}}
{{- $global := .Values.global.observability }}
{{- $svc := (.Values.config | default dict).observability | default dict }}
{{- $enabled := ternary (index $svc "otlpEnabled") $global.otlpEnabled (hasKey $svc "otlpEnabled") }}
{{- $endpoint := $svc.otlpEndpoint | default $global.otlpEndpoint | trim }}
{{- if not (or (hasPrefix "http://" $endpoint) (hasPrefix "https://" $endpoint)) }}
{{- $endpoint = printf "http://%s" $endpoint }}
{{- end }}
{{- $hostPort := $endpoint | trimPrefix "http://" | trimPrefix "https://" | trimSuffix "/" }}
{{- $ingest := printf "^ingest(\\.%s(\\.svc(\\.cluster\\.local)?)?)?:4317$" (regexQuoteMeta .Release.Namespace) }}
{{- $systemToken := ternary $global.systemToken (regexMatch $ingest $hostPort) (hasKey $global "systemToken") }}
{{- $remote := $global.remote | default dict }}
{{- $secret := $remote.tokenSecret | default dict }}
{{- if and $secret.name (eq $secret.name .Values.global.masterKey.secretName) }}
{{- fail "global.observability.remote.tokenSecret names the master key Secret; the remote takes an ingest token its cluster issued" }}
{{- end }}
{{- if and (or $secret.name $secret.key) (not (and $secret.name $secret.key)) }}
{{- fail "global.observability.remote.tokenSecret needs both name and key, or neither" }}
{{- end }}
{{- with $remote.endpoint }}
{{- if not (or (hasPrefix "http://" .) (hasPrefix "https://" .)) }}
{{- fail (printf "global.observability.remote.endpoint %s needs an http:// or https:// scheme" .) }}
{{- end }}
{{- else }}
{{- if $secret.name }}
{{- fail "global.observability.remote.tokenSecret is set without global.observability.remote.endpoint" }}
{{- end }}
{{- end }}
localEnabled: {{ eq (toString $enabled) "true" }}
localEndpoint: {{ $endpoint | quote }}
systemToken: {{ eq (toString $systemToken) "true" }}
remoteEndpoint: {{ $remote.endpoint | default "" | quote }}
remoteTokenSecret:
{{- if $secret.name }}
  name: {{ $secret.name | quote }}
  key: {{ $secret.key | quote }}
{{- else }} {}
{{- end }}
{{- end }}

{{/*
The remote's ingest token, from its Secret, as BZRK_OTLP_REMOTE_TOKEN: the
carrier the Rust services' config.yaml substitutes into
observability.remote.token, and the UI reads at boot.
*/}}
{{- define "berserk-common.env.otlp-remote-token" -}}
{{- $d := include "berserk-common.otlp-destinations" . | fromYaml }}
{{- if and $d.remoteEndpoint $d.remoteTokenSecret.name }}
- name: BZRK_OTLP_REMOTE_TOKEN
  valueFrom:
    secretKeyRef:
      name: {{ $d.remoteTokenSecret.name }}
      key: {{ $d.remoteTokenSecret.key }}
{{- end }}
{{- end }}

{{/*
The UI's destinations, which config/runtime.exs reads at boot: the local
endpoint while export is on, whether it carries the system ingest token, and the
remote endpoint. The remote's token comes from berserk-common.env.otlp-remote-token.
*/}}
{{- define "berserk-common.env.otlp-ui" -}}
{{- $d := include "berserk-common.otlp-destinations" . | fromYaml }}
{{- if $d.localEnabled }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $d.localEndpoint | quote }}
{{- end }}
- name: BZRK_OTLP_SYSTEM_TOKEN
  value: {{ ternary "true" "false" $d.systemToken | quote }}
{{- with $d.remoteEndpoint }}
- name: BZRK_OTLP_REMOTE_ENDPOINT
  value: {{ . | quote }}
{{- end }}
{{- end }}
