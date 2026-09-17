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
Readiness probe on the app's /up route (see config/routes.rb —
unauthenticated, only returns 200 once db:migrate has already completed).
Shared by codeveira-app; codeveira-sidekiq runs no server and has no probe.

Deliberately NOT reused for liveness: failing readiness early is harmless
(kubelet just withholds the pod from the Service until it passes), but the
same short fuse on liveness would have kubelet SIGKILL-restart the container
while entrypoint.sh is still mid `db:migrate` on a fresh install or a heavy
migration -- the exact scenario docker-compose.yml's own `app` healthcheck
calls out with its 90s start_period comment. Pair with
codeveira-common.startupProbe (below), which is what actually absorbs that
slow-boot window for liveness instead.
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

{{/*
Startup probe on the same /up route -- gates readiness/livenessProbe from
being evaluated at all until this succeeds once, so a slow first migration
can never trip the (much stricter) liveness probe into killing the
container mid-boot. periodSeconds 5 * failureThreshold 30 = 150s grace,
comfortably above docker-compose.yml's 90s start_period for the same
entrypoint.sh boot path.
*/}}
{{- define "codeveira-common.startupProbe" -}}
httpGet:
  path: /up
  port: http
periodSeconds: 5
timeoutSeconds: 5
failureThreshold: 30
{{- end }}

{{/*
Liveness probe on /up. Safe to run on a short fuse (unlike httpProbe above,
which is readiness-only) only because startupProbe has already guaranteed
one successful check before kubelet ever evaluates this one.
*/}}
{{- define "codeveira-common.livenessProbe" -}}
httpGet:
  path: /up
  port: http
periodSeconds: 10
timeoutSeconds: 5
failureThreshold: 3
{{- end }}
