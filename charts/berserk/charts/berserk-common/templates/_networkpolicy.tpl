{{/*
Generate a NetworkPolicy resource.

Requires per-service values under .Values.networkPolicy:
  allowExternal:       bool   - allow ingress from any source on service ports
  allowExternalEgress: bool   - allow egress to global.networkPolicy.externalEgress CIDRs
  ingressFrom:         list   - [{app, ports: [{port, protocol?}]}]
  egressTo:            list   - [{app, ports: [{port, protocol?}]}]
  additionalIngress:   list   - raw NetworkPolicy ingress rules
  additionalEgress:    list   - raw NetworkPolicy egress rules
  scrapeEgress:        bool   - egress to every operator /metrics port in the release
  kubeApiEgress:       bool   - egress to the Kubernetes API server

Global values under .Values.global.networkPolicy:
  enabled:             bool   - master switch
  additionalIngress:   list   - raw ingress rules applied to ALL services
  externalEgress:      list   - [{cidr, ports: [{port, protocol}]}]
  otlpEgress:          list   - egress rules for external OTLP collectors
  scrape:              map    - operator /metrics scrape access; see values.yaml
*/}}
{{- define "berserk-common.networkpolicy" -}}
{{- if .Values.global.networkPolicy.enabled }}
{{- $scrape := .Values.global.networkPolicy.scrape | default dict }}
{{- /* This pod's own operator /metrics port, read from its own
       `prometheus.io/port` annotation — the same value the scrape discovery keys
       on. Deriving it means the policy cannot drift from the endpoint it
       protects: metricsPort, the annotation and the opened port become one value
       with one edit site. Empty when this pod is not annotated for scraping. */ -}}
{{- $ann := .Values.podAnnotations | default dict }}
{{- $metricsPort := "" }}
{{- if eq (index $ann "prometheus.io/scrape" | default "" | toString) "true" }}
{{- $metricsPort = index $ann "prometheus.io/port" | default "" | toString }}
{{- end }}
{{- /* Drift guard: a renumbered operator port becomes a build error here rather
       than a silent connection timeout discovered weeks later. Mirrors the
       `fail` on malformed otlpEgress entries below. */ -}}
{{- if and $scrape.enabled $metricsPort }}
{{- $allowed := list }}
{{- range ($scrape.operatorPorts | default list) }}{{ $allowed = append $allowed (toString .) }}{{ end }}
{{- if not (has $metricsPort $allowed) }}
{{- fail (printf "%s: prometheus.io/port %s is not listed in global.networkPolicy.scrape.operatorPorts %v — add it there (it is the allowlist a scraping service may egress to), or set global.networkPolicy.scrape.enabled=false" .Chart.Name $metricsPort $allowed) }}
{{- end }}
{{- end }}
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
    {{- /* Rule: operator /metrics scrape ingress (#4122). ONE generic rule rather
           than enumerating every scraper -> service port pair: this opens THIS
           pod's own operator port to the peers in
           global.networkPolicy.scrape.from. Without it an install with
           networkPolicy.enabled has no path to any operator /metrics port at all,
           so the bundled Prometheus and ui's in-product collector both fail
           closed, silently.

           NB for services whose /metrics rides the main service port (meta 9560,
           ingest 9550, nursery 9530, permissions 9580) this necessarily also opens
           that port to those peers; query 9511, janitor 9502, gateway 9502 and ui
           9571 have dedicated operator listeners.

           The `from` non-empty guard is load-bearing: a NetworkPolicy rule with an
           empty `from` means "from anywhere", so an empty list must disable the
           rule rather than open the port to the world. */ -}}
    {{- if and $scrape.enabled $metricsPort $scrape.from }}
    - from:
        {{- range $scrape.from }}
        {{- if .cidr }}
        - ipBlock:
            cidr: {{ .cidr }}
        {{- else if .namespace }}
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: {{ .namespace }}
          {{- with .podLabels }}
          podSelector:
            matchLabels:
              {{- range $k, $v := . }}
              {{ $k }}: {{ $v | quote }}
              {{- end }}
          {{- end }}
        {{- /* Same namespace, label for label. Unlike `app` below this does NOT
               AND in app.kubernetes.io/instance: the bundled Prometheus pod
               carries `app: prometheus` and no instance label, so an `app` entry
               would never match it. */}}
        {{- else if .podLabels }}
        - podSelector:
            matchLabels:
              {{- range $k, $v := .podLabels }}
              {{ $k }}: {{ $v | quote }}
              {{- end }}
        {{- else if .app }}
        - podSelector:
            matchLabels:
              app: {{ .app }}
              app.kubernetes.io/instance: {{ $.Release.Name }}
        {{- else }}
        {{- fail "global.networkPolicy.scrape.from entry must set 'app', 'podLabels', 'namespace' (+ optional 'podLabels'), or 'cidr'" }}
        {{- end }}
        {{- end }}
      ports:
        - port: {{ $metricsPort | int }}
          protocol: TCP
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
    {{- /* External: each otlpEgress entry must specify {cidr} for an ipBlock
           rule, {namespace, podLabels} for a cross-namespace in-cluster peer,
           or {anyDestination: true} for a port-scoped rule with no destination
           selector. The last form exists for host-network collectors (e.g. a
           node-local agent): some CNIs (Cilium / GKE Dataplane V2) never match
           host identities with ipBlock or podSelector, and a rule without a
           `to` clause is the only shape they apply to such destinations. */ -}}
    {{- range .Values.global.networkPolicy.otlpEgress }}
    {{- if .anyDestination }}
    - ports:
        {{- range .ports }}
        - port: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
    {{- else }}
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
        {{- fail "otlpEgress entry must set 'cidr', 'namespace' + 'podLabels', or 'anyDestination: true'" }}
        {{- end }}
      ports:
        {{- range .ports }}
        - port: {{ .port }}
          protocol: {{ .protocol | default "TCP" }}
        {{- end }}
    {{- end }}
    {{- end }}
    {{- end }}
    {{- end }}
    {{- /* Rule: operator /metrics scrape egress (#4122). For a service that scrapes
           its peers — today only ui, which runs the in-product collector. ONE rule
           for the whole release (any pod of this release, on any operator port)
           rather than one per peer: adding a service, or gateway and janitor
           sharing 9502, needs no edit here, and the port list has exactly one home
           in global.networkPolicy.scrape.operatorPorts. */ -}}
    {{- if and .Values.networkPolicy.scrapeEgress $scrape.operatorPorts }}
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/instance: {{ .Release.Name }}
      ports:
        {{- range $scrape.operatorPorts }}
        - port: {{ . | int }}
          protocol: TCP
        {{- end }}
    {{- end }}
    {{- /* Rule: Kubernetes API server egress (#4122) — in-cluster pod discovery.
           The API server is not a pod in this namespace, so it needs an ipBlock;
           see global.networkPolicy.kubeApiEgress for the post-DNAT port caveat. */ -}}
    {{- if .Values.networkPolicy.kubeApiEgress }}
    {{- range .Values.global.networkPolicy.kubeApiEgress }}
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
    {{- /* Rule: per-service additional egress */ -}}
    {{- with .Values.networkPolicy.additionalEgress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}
