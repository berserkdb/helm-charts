{{/*
Generate a NetworkPolicy resource.

Requires per-service values under .Values.networkPolicy:
  allowExternal:       bool   - allow ingress from any source on service ports
  allowExternalEgress: bool   - allow egress to global.networkPolicy.externalEgress CIDRs
  ingressFrom:         list   - [{app, ports: [{port, protocol?}]}]
  egressTo:            list   - [{app, ports: [{port, protocol?}]}]
  additionalIngress:   list   - raw NetworkPolicy ingress rules
  additionalEgress:    list   - raw NetworkPolicy egress rules

Global values under .Values.global.networkPolicy:
  enabled:             bool   - master switch
  additionalIngress:   list   - raw ingress rules applied to ALL services
  externalEgress:      list   - [{cidr, ports: [{port, protocol}]}]
  otlpEgress:          list   - egress rules for external OTLP collectors
*/}}
{{- define "berserk-common.networkpolicy" -}}
{{- if .Values.global.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "berserk-common.fullname" . }}
  labels:
    {{- include "berserk-common.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "berserk-common.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    {{- /* Rule: allow ingress from specific Berserk peer pods */ -}}
    {{- range .Values.networkPolicy.ingressFrom }}
    - from:
        - podSelector:
            matchLabels:
              app: {{ .app }}
              app.kubernetes.io/instance: {{ $.Release.Name }}
      ports:
        {{- range .ports }}
        - port: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
    {{- end }}
    {{- /* Rule: allow external ingress (no from restriction) on service ports */ -}}
    {{- if .Values.networkPolicy.allowExternal }}
    - ports:
        {{- if .Values.service.ports }}
        {{- range $name, $port := .Values.service.ports }}
        - port: {{ $port }}
          protocol: TCP
        {{- end }}
        {{- else if .Values.service }}
        - port: {{ .Values.service.targetPort | default .Values.service.port }}
          protocol: TCP
        {{- end }}
    {{- end }}
    {{- /* Rule: OTLP ingress -- when this service is the OTLP target, allow namespace-wide ingress */ -}}
    {{- if .Values.global.observability.otlpEnabled }}
    {{- $otlpIngressEndpoint := .Values.global.observability.otlpEndpoint | default "ingest:4317" | trimPrefix "https://" | trimPrefix "http://" }}
    {{- $otlpIngressHost := index (splitList ":" $otlpIngressEndpoint) 0 }}
    {{- $otlpIngressPort := index (splitList ":" $otlpIngressEndpoint) 1 | default "4317" }}
    {{- if eq $otlpIngressHost .Chart.Name }}
    - from:
        - podSelector: {}
      ports:
        - port: {{ $otlpIngressPort | int }}
          protocol: TCP
    {{- end }}
    {{- end }}
    {{- /* Rule: global additional ingress */ -}}
    {{- with .Values.global.networkPolicy.additionalIngress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
    {{- /* Rule: per-service additional ingress */ -}}
    {{- with .Values.networkPolicy.additionalIngress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  egress:
    {{- /* Rule: DNS - always allowed */}}
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    {{- /* Rule: egress to specific Berserk peer pods */ -}}
    {{- range .Values.networkPolicy.egressTo }}
    - to:
        - podSelector:
            matchLabels:
              app: {{ .app }}
              app.kubernetes.io/instance: {{ $.Release.Name }}
      ports:
        {{- range .ports }}
        - port: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
    {{- end }}
    {{- /* Rule: external egress (S3, PostgreSQL, etc.) via CIDR allowlist */ -}}
    {{- if .Values.networkPolicy.allowExternalEgress }}
    {{- range .Values.global.networkPolicy.externalEgress }}
    - to:
        - ipBlock:
            cidr: {{ .cidr }}
      ports:
        {{- range .ports }}
        - port: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
    {{- end }}
    {{- end }}
    {{- if .Values.global.observability.otlpEnabled }}
    {{- $otlpEndpoint := .Values.global.observability.otlpEndpoint | default "ingest:4317" | trimPrefix "https://" | trimPrefix "http://" }}
    {{- $otlpHost := index (splitList ":" $otlpEndpoint) 0 }}
    {{- $otlpPort := index (splitList ":" $otlpEndpoint) 1 | default "4317" }}
    {{- if eq $otlpHost "ingest" }}
    - to:
        - podSelector:
            matchLabels:
              app: ingest
              app.kubernetes.io/instance: {{ .Release.Name }}
      ports:
        - port: {{ $otlpPort | int }}
          protocol: TCP
    {{- else }}
    {{- /* External: each otlpEgress entry must specify either {cidr} for an
           ipBlock rule, or {namespace, podLabels} for a cross-namespace
           in-cluster peer. */ -}}
    {{- range .Values.global.networkPolicy.otlpEgress }}
    - to:
        {{- if .cidr }}
        - ipBlock:
            cidr: {{ .cidr }}
        {{- else if .namespace }}
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .namespace }}
          podSelector:
            matchLabels:
              {{- range $k, $v := .podLabels }}
              {{ $k }}: {{ $v | quote }}
              {{- end }}
        {{- else }}
        {{- fail "otlpEgress entry must set either 'cidr' or 'namespace' + 'podLabels'" }}
        {{- end }}
      ports:
        {{- range .ports }}
        - port: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
    {{- end }}
    {{- end }}
    {{- end }}
    {{- /* Rule: per-service additional egress */ -}}
    {{- with .Values.networkPolicy.additionalEgress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}
