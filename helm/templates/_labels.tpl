{{- define "secrets-app-chart.backendLabels" -}}
app.kubernetes.io/name: {{ .Values.appConfig.appName }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance:	{{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/component: backend
{{- end -}}

{{- define "secrets-app-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ .Values.appConfig.appName }}
{{- end }}