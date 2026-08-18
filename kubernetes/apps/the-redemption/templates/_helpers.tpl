{{/*
Expand the name of the chart.
*/}}
{{- define "the-redemption.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name. If release name contains
chart name it will be used as a full name.
*/}}
{{- define "the-redemption.fullname" -}}
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
Selector labels.
*/}}
{{- define "the-redemption.selectorLabels" -}}
app.kubernetes.io/name: {{ include "the-redemption.name" . }}
{{- end }}

{{/*
Standard labels. Mirrors the naming/tagging taxonomy used on the AWS
side (see docs/ARCHITECTURE.md), so cloud tags and k8s labels are one
vocabulary, not two.
*/}}
{{- define "the-redemption.labels" -}}
{{ include "the-redemption.selectorLabels" . }}
app.kubernetes.io/part-of: redemption
app.kubernetes.io/managed-by: argocd
environment: {{ .Values.environment }}
{{- end -}}
