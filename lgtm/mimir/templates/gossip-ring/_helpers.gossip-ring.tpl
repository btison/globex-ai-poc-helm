{{/*
gossip-ring selector labels
*/}}
{{- define "mimir.gossipRingSelectorLabels" -}}
{{ include "mimir.selectorLabels" (dict "ctx" .) }}
app.kubernetes.io/part-of: memberlist
{{- end -}}
