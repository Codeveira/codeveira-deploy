{{/*
Fully qualified app name: <release>-<chart name>, unless the release name
already contains the chart name.
*/}}
{{- define "codeveira-common.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Standard labels, shared across every subchart's resources.
*/}}
{{- define "codeveira-common.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: codeveira
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{/*
Selector labels — a stable subset of the above, must never change across
releases of the same workload or Deployment/StatefulSet selectors break.
*/}}
{{- define "codeveira-common.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Liveness/readiness probe on the app's /up route (see config/routes.rb —
unauthenticated, only returns 200 once db:migrate has already completed).
Shared by codeveira-app; codeveira-sidekiq runs no server and has no probe.
*/}}
{{- define "codeveira-common.httpProbe" -}}
httpGet:
  path: /up
  port: http
initialDelaySeconds: 10
periodSeconds: 10
timeoutSeconds: 5
failureThreshold: 5
{{- end }}
