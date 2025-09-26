{{/*
Expand the name of the chart.
*/}}
{{- define "kafka-connect.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kafka-connect.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "kafka-connect.build.imageStream" -}}
{{- if .Values.build.imageStreamOverride }}
{{- .Values.build.imageStreamOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" $name "build" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kafka-connect.labels" -}}
helm.sh/chart: {{ include "kafka-connect.chart" . }}
{{ include "kafka-connect.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kafka-connect.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kafka-connect.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Annotations
*/}}
{{- define "kafka-connect.annotations" -}}
strimzi.io/use-connector-resources: 'true'
{{- if .Values.argocd }}
{{- if and (.Values.argocd.syncwave) (.Values.argocd.enabled) }}
argocd.argoproj.io/sync-wave: "{{ .Values.argocd.syncwave }}"
{{- end }}
{{- end }}
{{- end }}

{{/*
ArgoCD Syncwave
*/}}
{{- define "kafka-connect.argocd-syncwave" -}}
{{- if .Values.argocd }}
{{- if and (.Values.argocd.syncwave) (.Values.argocd.enabled) -}}
argocd.argoproj.io/sync-wave: "{{ .Values.argocd.syncwave }}"
{{- else }}
{{- "{}" }}
{{- end }}
{{- else }}
{{- "{}" }}
{{- end }}
{{- end }}

{{/*
Kafka Client Secret
*/}}
{{- define "kafka-connect.client-connection-secret" }}
{{- $secretObj := (lookup "v1" "Secret" .Values.kafka.namespace (include "kafka.client-connection-secret.name" . )) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
{{- $bootstrapServer := (get $secretData "bootstrapServer") }}
{{- $securityProtocol := (get $secretData "securityProtocol") }}
{{- $saslMechanism := (get $secretData "saslMechanism") }}
{{- $clientId := (get $secretData "clientId") }}
{{- $clientSecret := (get $secretData "clientSecret") }}
bootstrapServer: {{ $bootstrapServer}}
securityProtocol: {{ $securityProtocol }}
saslMechanism: {{ $saslMechanism }}
clientId: {{ $clientId }}
clientSecret: {{ $clientSecret }}
{{- end }}

{{/*
Kafka Authentication type
*/}}
{{- define "kafka-connect.authentication-type" }}
{{- $saslMechanism := (include "kafka.sasl-mechanism" .) }}
{{- $output := "scram-sha-512" }}
{{- if eq "PLAIN" $saslMechanism }}
{{- $output = "plain" }}
{{- else if eq "SCRAM-SHA-512" $saslMechanism}}
{{- $output = "scram-sha-512"}}
{{- end }}
{{- $output }}
{{- end }}

{{/*
Kafka Authentication TLS
*/}}
{{- define "kafka-connect.tls" }}
{{- $securityProtocol := (include "kafka.security-protocol" .) }}
{{- $output := "" }}
{{- if eq "SASL_SSL" $securityProtocol }}
{{- $output = "1" }}
{{- end }}
{{- $output }}
{{- end }}

{{/*
Kafka Client Connection Secret Name
*/}}
{{- define "kafka.client-connection-secret.name" }}
{{- $clientId := (include "kafka.client-id" .) }}
{{- $secretName := printf "%s-client-secret" $clientId }}
{{- $secretName }}
{{- end }}

{{/*
Kafka Client Secret Absent?
*/}}
{{- define "kafka.client-connection-secret.absent" }}
{{- $output := "" }}
{{- if not .Values.kafka.bootstrapServer }}
{{- $secretObj := (lookup "v1" "Secret" .Release.Namespace (include "kafka.client-connection-secret.name" . )) | default dict }}
{{- if not $secretObj }}
{{- $output = "1" }}
{{- end }}
{{- end }}
{{- $output }}
{{- end }}

{{/*
Kafka Client Secret Namespace
*/}}
{{- define "kafka.client-connection-secret.namespace" }}
{{- if (include "kafka.client-connection-secret.absent" . ) }}
{{- .Values.kafka.namespace }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Kafka Bootstrap Server
*/}}
{{- define "kafka.bootstrap-server" }}
{{- $output := "" }}
{{- if .Values.kafka.bootstrapServer }}
{{- $output = .Values.kafka.bootstrapServer }}
{{- else }}
{{- $secretObj := (lookup "v1" "Secret" (include "kafka.client-connection-secret.namespace" .) (include "kafka.client-connection-secret.name" . )) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
{{- $bootstrapServer := (get $secretData "bootstrapServer") | b64dec }}
{{- $output = $bootstrapServer }}
{{- end }}
{{- $output }}
{{- end }}

{{/*
Kafka Client Authentication
*/}}
{{- define "kafka.authentication" }}
{{- $output := "" }}
{{- if .Values.kafka.clientId }}
{{- $output = "1" }}
{{- else }}
{{- $secretObj := (lookup "v1" "Secret" (include "kafka.client-connection-secret.namespace" .) (include "kafka.client-connection-secret.name" . )) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
{{- $clientId := (get $secretData "clientId") | b64dec }}
{{- if $clientId }}
{{- $output = "1" }}
{{- end }}
{{- end }}
{{- $output }}
{{- end }}

{{/*
Kafka Sasl Mechanism
*/}}
{{- define "kafka.sasl-mechanism" }}
{{- $output := "" }}
{{- if .Values.kafka.saslMechanism }}
{{- $output = .Values.kafka.saslMechanism }}
{{- else }}
{{- $secretObj := (lookup "v1" "Secret" (include "kafka.client-connection-secret.namespace" .) (include "kafka.client-connection-secret.name" . )) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
{{- $saslMechanism := (get $secretData "saslMechanism") | b64dec }}
{{- $output = $saslMechanism }}
{{- end }}
{{- $output }}
{{- end }}

{{/*
Kafka Security Protocol
*/}}
{{- define "kafka.security-protocol" }}
{{- $output := "" }}
{{- if .Values.kafka.securityProtocol }}
{{- $output = .Values.kafka.securityProtocol }}
{{- else }}
{{- $secretObj := (lookup "v1" "Secret" (include "kafka.client-connection-secret.namespace" .) (include "kafka.client-connection-secret.name" . )) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
{{- $securityProtocol := (get $secretData "securityProtocol") | b64dec }}
{{- $output = $securityProtocol }}
{{- end }}
{{- $output }}
{{- end }}

{{/*
Kafka Client Id
*/}}
{{- define "kafka.client-id" }}
{{- $output := "" }}
{{- if .Values.kafka.clientId }}
{{- $output = .Values.kafka.clientId }}
{{- else }}
{{- $secretObj := (lookup "v1" "Secret" (include "kafka.client-connection-secret.namespace" .) (include "kafka.client-connection-secret.name" . )) | default dict }}
{{- $secretData := (get $secretObj "data") | default dict }}
{{- $clientId := (get $secretData "clientId") | b64dec }}
{{- $output = $clientId }}
{{- end }}
{{- $output }}
{{- end }}

{{/*
ArgoCD Syncwave Hook
*/}}
{{- define "kafka-connect-hook.argocd-syncwave" -}}
{{- if .Values.hook.argocd }}
{{- if and (.Values.hook.argocd.syncwave) (.Values.hook.argocd.enabled) -}}
argocd.argoproj.io/sync-wave: "{{ .Values.hook.argocd.syncwave }}"
{{- else }}
{{- "{}" }}
{{- end }}
{{- else }}
{{- "{}" }}
{{- end }}
{{- end }}