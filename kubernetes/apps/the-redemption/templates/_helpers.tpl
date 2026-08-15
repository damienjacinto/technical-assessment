{{/*
Standard labels -- mirrors the naming/tagging taxonomy used on the AWS
side (see docs/ARCHITECTURE.md), so cloud tags and k8s labels are one
vocabulary, not two.
*/}}
{{- define "the-redemption.labels" -}}
app.kubernetes.io/name: the-redemption
app.kubernetes.io/part-of: redemption
app.kubernetes.io/managed-by: argocd
environment: {{ .Values.environment }}
{{- end -}}
