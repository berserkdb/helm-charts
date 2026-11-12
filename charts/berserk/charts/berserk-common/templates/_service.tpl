{{/*
Generate a complete Service resource.

Supports three port patterns via values:
  1. Single port: .Values.service.port (targetPort defaults to port)
  2. Single port with different targetPort: .Values.service.port + .Values.service.targetPort
  3. Multi-port map: .Values.service.ports (map of camelCase name -> port number)

Additional values:
  - .Values.service.type (required, e.g. ClusterIP)
  - .Values.service.portName (optional, defaults to "http")
  - .Values.service.appProtocols (optional, map of camelCase port name ->
    appProtocol, keyed like .Values.service.ports). Gateway API implementations
    and service meshes read `appProtocol` to pick the protocol they speak to the
    port, e.g. `kubernetes.io/h2c` for gRPC without TLS. A key that names no
    port fails the render.
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
    {{- include "berserk-common.service.ports" . | trim | nindent 4 }}
{{- end }}

{{/*
Port list shared by `berserk-common.service` and `berserk-common.service.headless`,
rendered without indentation. Callers place it with `trim | nindent <n>`.

`appProtocol` says what the port speaks, which holds for either Service, so the
headless one carries it too.
*/}}
{{- define "berserk-common.service.ports" -}}
{{- $appProtocols := .Values.service.appProtocols | default dict }}
{{- range $name, $_ := $appProtocols }}
{{- if not (hasKey ($.Values.service.ports | default dict) $name) }}
{{- fail (printf "%s: service.appProtocols.%s names no port in service.ports" (include "berserk-common.fullname" $) $name) }}
{{- end }}
{{- end }}
{{- if .Values.service.ports }}
{{- range $name, $port := .Values.service.ports }}
- port: {{ $port }}
  targetPort: {{ $port }}
  protocol: TCP
  name: {{ $name | kebabcase }}
  {{- with get $appProtocols $name }}
  appProtocol: {{ . | quote }}
  {{- end }}
{{- end }}
{{- else }}
- port: {{ .Values.service.port }}
  targetPort: {{ .Values.service.targetPort | default .Values.service.port }}
  protocol: TCP
  name: {{ .Values.service.portName | default "http" }}
{{- end }}
{{- end }}

{{/*
Headless companion to a service's primary Service.

A ClusterIP Service load-balances per TCP connection, so a gRPC client — which
multiplexes every RPC over one long-lived HTTP/2 connection — pins to whichever
pod it first dialled, for the process lifetime. This Service resolves to one A
record per Ready pod instead of a single VIP, letting a client hold one
connection per pod and spread requests across them.

Rendered unconditionally by the subcharts that include it: with no proxying and
no VIP it costs nothing but DNS records. Which callers actually use it is decided
by the endpoint they are configured with (e.g. the gateway's `grpc_routes`
upstream, or a collector's OTLP endpoint), which keeps it out of the rollout
decision. A gRPC client also needs a load-balancing policy — one address per pod
does nothing on its own, since the default `pick_first` still picks one.

Deliberately not rendered, unlike `berserk-common.service`:
  - `.Values.service.annotations` — proxy hints such as Traefik's
    `service.serversscheme` must not land here, because this Service is never an
    Ingress backend. A proxy pooling to one pod would recreate the pin it exists
    to remove.
  - `externalIPs` — there is no VIP to alias.
  - `publishNotReadyAddresses` stays at its default, so membership is Ready-only;
    that is what makes a client's endpoint set correct.

Not a StatefulSet's `serviceName` either — that field is immutable on a live
object, so repointing it would be a delete-with-`--cascade=orphan` migration per
namespace.
*/}}
{{- define "berserk-common.service.headless" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ printf "%s-headless" (include "berserk-common.fullname" .) }}
  labels:
    {{- include "berserk-common.labels" . | nindent 4 }}
    component: {{ .Values.component | default "backend" }}
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    {{- include "berserk-common.selectorLabels" . | nindent 4 }}
  ports:
    {{- include "berserk-common.service.ports" . | trim | nindent 4 }}
{{- end }}
