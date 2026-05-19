{{/*
Generate an Ingress resource (networking.k8s.io/v1).

Renders only when .Values.ingress.enabled is true. The Service named by
"berserk-common.fullname" is the backend; per-path port selection lets a
single Ingress fan out to multiple Service ports (e.g. ingest exposes
otlp-grpc on 4317 and otlp-http on 4318).

Values:
  - .Values.ingress.enabled (bool, default false)
  - .Values.ingress.className (string, optional). Empty -> use cluster default
    IngressClass (the modern equivalent of the legacy
    `kubernetes.io/ingress.class` annotation, which we deliberately do not
    set).
  - .Values.ingress.annotations (map). Pass-through; this is where customers
    wire controller-specific behavior:
      nginx:    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
      traefik:  traefik.ingress.kubernetes.io/service.serversscheme: "h2c"
      cert-mgr: cert-manager.io/cluster-issuer: "letsencrypt-prod"
  - .Values.ingress.hosts (list). Each entry:
      host: <fqdn>
      paths:
        - path: /
          pathType: Prefix          # required in v1
          portName: <svc port name> # optional; defaults to first/single port
          # OR portNumber: 4317     # also accepted
  - .Values.ingress.tls (list of {hosts: [...], secretName: ...})
*/}}
{{- define "berserk-common.ingress" -}}
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "berserk-common.fullname" . }}
  labels:
    {{- include "berserk-common.labels" . | nindent 4 }}
    component: {{ .Values.component | default "backend" }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with .Values.ingress.className }}
  ingressClassName: {{ . | quote }}
  {{- end }}
  {{- with .Values.ingress.tls }}
  tls:
    {{- range . }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      {{- with .secretName }}
      secretName: {{ . | quote }}
      {{- end }}
    {{- end }}
  {{- end }}
  rules:
    {{- $svcName := include "berserk-common.fullname" . }}
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path | quote }}
            pathType: {{ .pathType | default "Prefix" | quote }}
            backend:
              service:
                name: {{ $svcName }}
                port:
                  {{- if .portNumber }}
                  number: {{ .portNumber }}
                  {{- else if .portName }}
                  name: {{ .portName | quote }}
                  {{- else }}
                  {{- /* Default: first named port from .Values.service.ports
                         (multi-port map) or the single .Values.service.portName.
                         If neither resolves, fall back to "http" — matches
                         _service.tpl's single-port default. */ -}}
                  {{- if $.Values.service.ports }}
                  {{- $names := keys $.Values.service.ports | sortAlpha }}
                  name: {{ index $names 0 | kebabcase | quote }}
                  {{- else }}
                  name: {{ $.Values.service.portName | default "http" | quote }}
                  {{- end }}
                  {{- end }}
          {{- end }}
    {{- end }}
{{- end }}
{{- end }}
