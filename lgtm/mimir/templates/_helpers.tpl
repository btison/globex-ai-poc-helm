{{/*
Expand the name of the chart.
*/}}
{{- define "mimir.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "mimir.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Resource name template
Params:
  ctx = . context
  component = component name (optional)
  rolloutZoneName = rollout zone name (optional)
*/}}
{{- define "mimir.resourceName" -}}
{{- $resourceName := include "mimir.name" .ctx -}}
{{- if .component -}}{{- $resourceName = printf "%s-%s" $resourceName .component -}}{{- end -}}
{{- if gt (len $resourceName) 253 -}}{{- printf "Resource name (%s) exceeds kubernetes limit of 253 character. To fix: shorten release name if this will be a fresh install or shorten zone names (e.g. \"a\" instead of \"zone-a\") if using zone-awareness." $resourceName | fail -}}{{- end -}}
{{- $resourceName -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mimir.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resource labels
Params:
  ctx = . context
  component = component name (optional)
  rolloutZoneName = rollout zone name (optional)
*/}}
{{- define "mimir.labels" -}}
helm.sh/chart: {{ include "mimir.chart" .ctx }}
app.kubernetes.io/name: {{ include "mimir.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- if .memberlist }}
app.kubernetes.io/part-of: memberlist
{{- end }}
{{- if .ctx.Chart.AppVersion }}
app.kubernetes.io/version: {{ .ctx.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- end }}

{{/*
Service selector labels
Params:
  ctx = . context
  component = name of the component
*/}}
{{- define "mimir.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mimir.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- end -}}

{{/*
POD labels
Params:
  ctx = . context
  component = name of the component
  memberlist = true if part of memberlist gossip ring
*/}}
{{- define "mimir.podLabels" -}}
{{ with .ctx.Values.global.podLabels -}}
{{ toYaml . }}
{{- end -}}
helm.sh/chart: {{ include "mimir.chart" .ctx }}
app.kubernetes.io/name: {{ include "mimir.name" .ctx }}
app.kubernetes.io/instance: {{ .ctx.Release.Name }}
app.kubernetes.io/managed-by: {{ .ctx.Release.Service }}
{{- if .component }}
app.kubernetes.io/component: {{ .component }}
{{- end }}
{{- if .memberlist }}
app.kubernetes.io/part-of: memberlist
{{- end }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "mimir.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mimir.name" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Internal servers http listen port - derived from Mimir default
*/}}
{{- define "mimir.serverHttpListenPort" -}}
{{ (((.Values.mimir).structuredConfig).server).http_listen_port | default "8080" }}
{{- end -}}

{{/*
Internal servers grpc listen port - derived from Mimir default
*/}}
{{- define "mimir.serverGrpcListenPort" -}}
{{ (((.Values.mimir).structuredConfig).server).grpc_listen_port | default "9095" }}
{{- end -}}

{{/*
Memberlist bind port
*/}}
{{- define "mimir.memberlistBindPort" -}}
{{ (((.Values.mimir).structuredConfig).memberlist).bind_port | default "7946" }}
{{- end -}}

{{/*
Calculate the config from structured and unstructured text input
*/}}
{{- define "mimir.calculatedConfig" -}}
{{ tpl (mergeOverwrite (include "mimir.unstructuredConfig" . | fromYaml) .Values.mimir.structuredConfig | toYaml) . }}
{{- end -}}

{{/*
Calculate the config from the unstructured text input
*/}}
{{- define "mimir.unstructuredConfig" -}}
{{ include (print $.Template.BasePath "/_config-render.tpl") . }}
{{- end -}}

{{/*
Calculate minio bucket prefix name
*/}}
{{- define "mimir.minioBucketPrefix" -}}
mimir
{{- end -}}