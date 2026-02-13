{{/*
Generate a complete Service resource.

Supports three port patterns via values:
  1. Single port: .Values.service.port (targetPort defaults to port)
  2. Single port with different targetPort: .Values.service.port + .Values.service.targetPort
  3. Multi-port map: .Values.service.ports (map of camelCase name -> port number)

Additional values:
  - .Values.service.type (required, e.g. ClusterIP)
  - .Values.service.portName (optional, defaults to "http")
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
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "berserk-common.selectorLabels" . | nindent 4 }}
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
