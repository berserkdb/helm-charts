{{/*
Generate a complete Service resource.

Supports three port patterns via values:
  1. Single port: .Values.service.port (targetPort defaults to port)
  2. Single port with different targetPort: .Values.service.port + .Values.service.targetPort
  3. Multi-port map: .Values.service.ports (map of camelCase name -> port number)

Additional values:
  - .Values.service.type (required, e.g. ClusterIP)
  - .Values.service.portName (optional, defaults to "http")
  - .Values.service.annotations (optional, map of string -> string) — e.g.
    LoadBalancer-controller annotations, cert-manager hints, external-dns
    hostnames. Useful when a Service needs to be exposed via a public LB.
  - .Values.service.externalIPs (optional, list of string). Advanced: VIPs
    already bound to a node's network interface (e.g. WireGuard mesh) that
    the cluster should accept for this Service. kube-proxy DNATs traffic
    arriving at any of these IPs to a backing pod regardless of which node
    the pod runs on. For public exposure prefer `service.type: LoadBalancer`
    or an Ingress (see `_ingress.tpl`).
  - .Values.component (optional, defaults to "backend")
*/}}
{{- define "berserk-common.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "berserk-common.fullname" . }}
  labels:
    {{- include "berserk-common.labels" . | nindent 4 }}
    component: {{ .Values.component | default "backend" }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "berserk-common.selectorLabels" . | nindent 4 }}
  {{- with .Values.service.externalIPs }}
  externalIPs:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  ports:
    {{- if .Values.service.ports }}
    {{- range $name, $port := .Values.service.ports }}
    - port: {{ $port }}
      targetPort: {{ $port }}
      protocol: TCP
      name: {{ $name | kebabcase }}
    {{- end }}
    {{- else }}
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.targetPort | default .Values.service.port }}
      protocol: TCP
      name: {{ .Values.service.portName | default "http" }}
    {{- end }}
{{- end }}
