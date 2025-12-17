{{/*
Expand the name of the chart.
*/}}
{{- define "loki.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "loki.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "loki.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "loki.labels" -}}
helm.sh/chart: {{ include "loki.chart" . }}
{{ include "loki.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "loki.selectorLabels" -}}
app.kubernetes.io/name: {{ include "loki.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "loki.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "loki.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Allow the release namespace to be overridden for multi-namespace deployments in combined charts
*/}}
{{- define "loki.namespace" -}}
  {{- if .Values.namespaceOverride -}}
    {{- .Values.namespaceOverride -}}
  {{- else -}}
    {{- .Release.Namespace -}}
  {{- end -}}
{{- end -}}

{{/*
Calculate the config from structured and unstructured text input
*/}}
{{- define "loki.calculatedConfig" -}}
{{ tpl (mergeOverwrite (tpl .Values.loki.config . | fromYaml) .Values.loki.structuredConfig | toYaml) . }}
{{- end }}

{{/* Configure the correct name for the memberlist service */}}
{{- define "loki.memberlist" -}}
{{- if .Values.memberlist.service.name }}
{{- tpl .Values.memberlist.service.name $ }}
{{- else }}
{{- include "loki.name" . }}-memberlist
{{- end -}}
{{- end -}}

{{/* Allow KubeVersion to be overridden. */}}
{{- define "loki.kubeVersion" -}}
  {{- default .Capabilities.KubeVersion.Version .Values.kubeVersionOverride -}}
{{- end -}}

{{/*
compute a ConfigMap or Secret checksum only based on its .data content.
This function needs to be called with a context object containing the following keys:
- ctx: the current Helm context (what '.' is at the call site)
- name: the file name of the ConfigMap or Secret
*/}}
{{- define "loki.configMapOrSecretContentHash" -}}
{{ get (include (print .ctx.Template.BasePath .name) .ctx | fromYaml) "data" | toYaml | sha256sum }}
{{- end }}

{{/*
Return if deployment mode is simple scalable
*/}}
{{- define "loki.deployment.isScalable" -}}
  {{- and (eq (include "loki.isUsingObjectStorage" . ) "true") (or (eq .Values.deploymentMode "SingleBinary<->SimpleScalable") (eq .Values.deploymentMode "SimpleScalable") (eq .Values.deploymentMode "SimpleScalable<->Distributed")) }}
{{- end -}}

{{/*
Return if deployment mode is single binary
*/}}
{{- define "loki.deployment.isSingleBinary" -}}
  {{- or (eq .Values.deploymentMode "SingleBinary") (eq .Values.deploymentMode "SingleBinary<->SimpleScalable") }}
{{- end -}}

{{/*
Return if deployment mode is distributed
*/}}
{{- define "loki.deployment.isDistributed" -}}
  {{- and (eq (include "loki.isUsingObjectStorage" . ) "true") (or (eq .Values.deploymentMode "Distributed") (eq .Values.deploymentMode "SimpleScalable<->Distributed")) }}
{{- end -}}

{{/*
singleBinary fullname
*/}}
{{- define "loki.singleBinaryFullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := (include "loki.name" $) -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
singleBinary name
*/}}
{{- define "loki.singleBinaryName" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/* Determine compactor address based on target configuration */}}
{{- define "loki.compactorAddress" -}}
{{- $compactorAddress := "" -}}
{{/* single binary */}}
{{- $compactorAddress = include "loki.singleBinaryName" . -}}
{{- printf "%s.%s.svc.%s:%s" $compactorAddress .Release.Namespace .Values.global.clusterDomain (.Values.loki.server.grpc_listen_port | toString) }}
{{- end }}

{{/*
Generated storage config for loki common config
*/}}
{{- define "loki.commonStorageConfig" -}}
{{- if .Values.loki.storage.use_thanos_objstore -}}
{{- $bucketName := required "Please define loki.storage.bucketNames.chunks" (dig "storage" "bucketNames" "chunks" "" .Values.loki) }}
object_store:
  {{- include "loki.thanosStorageConfig" (dict "ctx" . "bucketName" $bucketName) | nindent 2 }}
{{- else if .Values.minio.enabled -}}
s3:
  endpoint: {{ include "loki.minio" $ }}
  bucketnames: chunks
  secret_access_key: {{ $.Values.minio.rootPassword }}
  access_key_id: {{ $.Values.minio.rootUser }}
  s3forcepathstyle: true
  insecure: true
{{- else if (eq (include "loki.isUsingObjectStorage" . ) "true")  -}}
{{- $bucketName := "" }}
{{- if not (or (dig "aws" "s3" "" .Values.loki.storage_config) (dig "aws" "bucketnames" "" .Values.loki.storage_config)) -}}
{{- $bucketName = required "Please define loki.storage.bucketNames.chunks" (dig "storage" "bucketNames" "chunks" "" .Values.loki) }}
{{- end -}}
{{- include "loki.lokiStorageConfig" (dict "ctx" . "bucketName" $bucketName) | nindent 0 }}
{{- else if .Values.loki.storage.filesystem }}
filesystem:
  {{- toYaml .Values.loki.storage.filesystem | nindent 2 }}
{{- end -}}
{{- end -}}

{{/*
Return the object store type for use with the test schema.
*/}}
{{- define "loki.testSchemaObjectStore" -}}
  {{- if .Values.minio.enabled -}}
    s3
  {{- else -}}
    filesystem
  {{- end -}}
{{- end -}}

{{/*
Storage config for ruler
*/}}
{{- define "loki.rulerStorageConfig" -}}
{{- if eq (dig "storage" "type" "" .Values.loki.rulerConfig) "local" -}}
type: "local"
{{- else if .Values.minio.enabled -}}
type: "s3"
s3:
  bucketnames: ruler
{{- else if (eq (include "loki.isUsingObjectStorage" . ) "true") }}
type: {{ .Values.loki.storage.type | quote }}
{{- $bucketName := required "Please define loki.storage.bucketNames.ruler" (dig "storage" "bucketNames" "ruler" "" .Values.loki) }}
{{- include "loki.lokiStorageConfig" (dict "ctx" . "bucketName" $bucketName) | nindent 0 }}
{{- else }}
type: "local"
{{- end }}
{{- end -}}

{{/* Determine index-gateway address */}}
{{- define "loki.indexGatewayAddress" -}}
{{- $idxGatewayAddress := ""}}
{{- $isDistributed := eq (include "loki.deployment.isDistributed" .) "true" -}}
{{- $isScalable := eq (include "loki.deployment.isScalable" .) "true" -}}
{{- if $isDistributed -}}
{{- $idxGatewayAddress = printf "dns+%s-headless.%s.svc.%s:%s" (include "loki.indexGatewayFullname" .) (include "loki.namespace" .) .Values.global.clusterDomain (.Values.loki.server.grpc_listen_port | toString) -}}
{{- end -}}
{{- if $isScalable -}}
{{- $idxGatewayAddress = printf "dns+%s-headless.%s.svc.%s:%s" (include "loki.backendFullname" .) (include "loki.namespace" .) .Values.global.clusterDomain (.Values.loki.server.grpc_listen_port | toString) -}}
{{- end -}}
{{- printf "%s" $idxGatewayAddress }}
{{- end }}

{{/* Determine query-scheduler address */}}
{{- define "loki.querySchedulerAddress" -}}
{{- $schedulerAddress := ""}}
{{- $isDistributed := eq (include "loki.deployment.isDistributed" .) "true" -}}
{{- if $isDistributed -}}
{{- $schedulerAddress = printf "%s.%s.svc.%s:%s" (include "loki.querySchedulerFullname" .) (include "loki.namespace" .) .Values.global.clusterDomain (.Values.loki.server.grpc_listen_port | toString) -}}
{{- end -}}
{{- printf "%s" $schedulerAddress }}
{{- end }}

{{/* Determine querier address */}}
{{- define "loki.querierAddress" -}}
{{- $querierAddress := "" }}
{{- $isDistributed := eq (include "loki.deployment.isDistributed" .) "true" -}}
{{- if $isDistributed -}}
{{- $querierHost := include "loki.querierFullname" .}}
{{- $querierUrl := printf "http://%s.%s.svc.%s:3100" $querierHost (include "loki.namespace" .) .Values.global.clusterDomain }}
{{- $querierAddress = $querierUrl }}
{{- end -}}
{{- printf "%s" $querierAddress }}
{{- end }}

{{/* Determine if deployment is using object storage */}}
{{- define "loki.isUsingObjectStorage" -}}
{{- has .Values.loki.storage.type (list "s3" "gcs" "azure" "swift" "alibabacloud" "cos" "bos") }}
{{- end -}}

{{/*
singleBinary common labels
*/}}
{{- define "loki.singleBinaryLabels" -}}
{{ include "loki.labels" . }}
app.kubernetes.io/component: single-binary
{{- end }}

{{/* singleBinary selector labels */}}
{{- define "loki.singleBinarySelectorLabels" -}}
{{ include "loki.selectorLabels" . }}
app.kubernetes.io/component: single-binary
{{- end }}

{{/* singleBinary replicas calculation */}}
{{- define "loki.singleBinaryReplicas" -}}
{{- $replicas := 1 }}
{{- $usingObjectStorage := eq (include "loki.isUsingObjectStorage" .) "true" }}
{{- if and $usingObjectStorage (gt (int .Values.singleBinary.replicas) 1)}}
{{- $replicas = int .Values.singleBinary.replicas -}}
{{- end }}
{{- printf "%d" $replicas }}
{{- end }}

{{/* Configure enableServiceLinks in pod */}}
{{- define "loki.enableServiceLinks" -}}
{{- if semverCompare ">=1.13-0" (include "loki.kubeVersion" .) -}}
{{- if or (.Values.loki.enableServiceLinks) (ne .Values.loki.enableServiceLinks false) -}}
enableServiceLinks: true
{{- else -}}
enableServiceLinks: false
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Pod security context
*/}}
{{- define "loki.podSecurityContext" -}}
{{- if semverCompare ">=1.23-0" $.Capabilities.KubeVersion.GitVersion }}
{{- toYaml .Values.loki.podSecurityContext }}
{{- else }}
{{- toYaml (omit .Values.loki.podSecurityContext "fsGroupChangePolicy")  }}
{{- end }}
{{- end -}}

{{/*
Docker image name for Loki
*/}}
{{- define "loki.lokiImage" -}}
{{- $dict := dict "service" .Values.loki.image "global" .Values.global.image "defaultVersion" .Chart.AppVersion -}}
{{- include "loki.baseImage" $dict -}}
{{- end -}}

{{/*
Base template for building docker image reference
*/}}
{{- define "loki.baseImage" }}
{{- $registry := .service.registry | default "" -}}
{{- $repository := .service.repository | default "" -}}
{{- $ref := ternary (printf ":%s" (.service.tag | default .defaultVersion | toString)) (printf "@%s" .service.digest) (empty .service.digest) -}}
{{- if and $registry $repository -}}
  {{- printf "%s/%s%s" $registry $repository $ref -}}
{{- else -}}
  {{- printf "%s%s%s" $registry $repository $ref -}}
{{- end -}}
{{- end -}}

{{/*
singleBinary target
*/}}
{{- define "loki.singleBinaryTarget" -}}
{{- .Values.singleBinary.targetModule -}}{{- if .Values.loki.ui.enabled -}},ui{{- end -}}
{{- end -}}

{{/*
The volume to mount for loki configuration
*/}}
{{- define "loki.configVolume" -}}
{{- if eq .Values.loki.configStorageType "Secret" -}}
secret:
  secretName: {{ tpl .Values.loki.configObjectName . }}
{{- else -}}
configMap:
  name: {{ tpl .Values.loki.configObjectName . }}
  items:
    - key: "config.yaml"
      path: "config.yaml"
{{- end -}}
{{- end -}}