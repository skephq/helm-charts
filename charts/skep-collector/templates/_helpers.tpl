{{/*
Names. The release name is the resource name (the install guide uses
skep-otelcol-<tier>, which edge agents' default gateway address expects).
*/}}
{{- define "skep-collector.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "skep-collector.name" -}}
{{- default "skep-otelcol" .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "skep-collector.tier" -}}
{{- if .Values.skep.tier -}}
{{- .Values.skep.tier -}}
{{- else if eq .Values.mode "agent" -}}
edge
{{- else -}}
gateway
{{- end -}}
{{- end -}}

{{- define "skep-collector.selectorLabels" -}}
app.kubernetes.io/name: {{ include "skep-collector.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "skep-collector.labels" -}}
{{ include "skep-collector.selectorLabels" . }}
app.kubernetes.io/component: {{ include "skep-collector.tier" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "skep-collector.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "skep-collector.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "skep-collector.secretName" -}}
{{- if .Values.secret.create -}}
{{- include "skep-collector.fullname" . -}}
{{- else -}}
{{- required "skep.existingSecret must name the Secret with SKEP_API_KEY" .Values.skep.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "skep-collector.image" -}}
{{- if .Values.image.digest -}}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest -}}
{{- else -}}
{{- printf "%s:%s" .Values.image.repository (default .Chart.AppVersion (toString .Values.image.tag)) -}}
{{- end -}}
{{- end -}}

{{/* The gateway runs one replica unless autoscaled; tail sampling forces one. */}}
{{- define "skep-collector.tail" -}}
{{- if and (eq .Values.mode "gateway") (eq .Values.sampling "tail_sampling") -}}true{{- end -}}
{{- end -}}

{{- define "skep-collector.autoscaled" -}}
{{- if and (eq .Values.mode "gateway") .Values.autoscaling.enabled (not (include "skep-collector.tail" .)) -}}true{{- end -}}
{{- end -}}

{{- define "skep-collector.multiReplica" -}}
{{- if and (eq .Values.mode "gateway") (not (include "skep-collector.tail" .)) (or (include "skep-collector.autoscaled" .) (gt (int .Values.replicaCount) 1)) -}}true{{- end -}}
{{- end -}}

{{/*
The collector's display name, as the install generator names it: the fleet,
else <environment>-<mode>; one per node for agents, one per pod for scaled
gateways.
*/}}
{{- define "skep-collector.collectorName" -}}
{{- $name := .Values.skep.collectorName | toString -}}
{{- if not $name -}}
{{- $name = default (printf "%s-%s" (toString .Values.skep.environment) .Values.mode) (toString .Values.skep.fleet) -}}
{{- end -}}
{{- if eq .Values.mode "agent" -}}
{{- printf "%s-$(K8S_NODE_NAME)" $name -}}
{{- else if include "skep-collector.multiReplica" . -}}
{{- printf "%s-$(POD_NAME)" $name -}}
{{- else -}}
{{- $name -}}
{{- end -}}
{{- end -}}

{{/* ws(s)://<host>/v1/opamp from the Skep endpoint, as the install generator derives it. */}}
{{- define "skep-collector.opampEndpoint" -}}
{{- if .Values.opamp.endpoint -}}
{{- .Values.opamp.endpoint -}}
{{- else -}}
{{- $u := urlParse .Values.skep.endpoint -}}
{{- $scheme := ternary "wss" "ws" (eq $u.scheme "https") -}}
{{- urlJoin (dict "scheme" $scheme "host" $u.host "path" "/v1/opamp") -}}
{{- end -}}
{{- end -}}

{{/*
The embedded configuration for these values: files/config/<mode>-<backend>
[-tail-sampling][-system-logs].yaml, rendered by the install generator
(TestChartConfigs keeps them in step).
*/}}
{{- define "skep-collector.configFile" -}}
{{- $f := printf "files/config/%s-%s" .Values.mode .Values.backend.type -}}
{{- if include "skep-collector.tail" . -}}{{- $f = printf "%s-tail-sampling" $f -}}{{- end -}}
{{- if .Values.systemLogs -}}{{- $f = printf "%s-system-logs" $f -}}{{- end -}}
{{- printf "%s.yaml" $f -}}
{{- end -}}

{{/* Option combinations the install generator refuses, refused the same way. */}}
{{- define "skep-collector.validate" -}}
{{- $mode := .Values.mode -}}
{{- if not (has $mode (list "agent" "gateway")) -}}
{{- fail "mode must be agent or gateway" -}}
{{- end -}}
{{- if not .Values.skep.endpoint -}}
{{- fail "skep.endpoint is required: Skep's URL as the collector reaches it" -}}
{{- end -}}
{{- $backend := .Values.backend.type -}}
{{- if eq $backend "file" -}}
{{- fail "writing telemetry to disk is available for Docker; on Kubernetes a pod's disk goes away with the pod, so use an OTLP backend" -}}
{{- end -}}
{{- if not (has $backend (list "none" "honeycomb" "otlp" "gateway")) -}}
{{- fail "backend.type must be one of none, honeycomb, otlp, gateway" -}}
{{- end -}}
{{- if and (eq $backend "otlp") (not .Values.backend.otlpEndpoint) -}}
{{- fail "backend.otlpEndpoint must be the http(s) URL of an OTLP/HTTP endpoint" -}}
{{- end -}}
{{- if eq $backend "gateway" -}}
{{- if ne (include "skep-collector.tier" .) "edge" -}}
{{- fail "only an edge tier forwards to a gateway" -}}
{{- end -}}
{{- if not .Values.backend.gatewayEndpoint -}}
{{- fail "backend.gatewayEndpoint must be the gateway's OTLP gRPC endpoint as host:port" -}}
{{- end -}}
{{- end -}}
{{- if not (has .Values.sampling (list "none" "tail_sampling")) -}}
{{- fail "sampling must be none or tail_sampling" -}}
{{- end -}}
{{- if and (eq $mode "agent") (eq .Values.sampling "tail_sampling") -}}
{{- fail "tail sampling needs every span of a trace in one collector; use the gateway mode for tail sampling" -}}
{{- end -}}
{{- if and .Values.systemLogs (ne $mode "agent") -}}
{{- fail "system logs are collected by agents (the edge tier), where the log files are" -}}
{{- end -}}
{{- if .Values.opamp.enabled -}}
{{- if not .Values.skep.fleet -}}
{{- fail "opamp.enabled needs skep.fleet: Skep pushes the fleet's deployed revisions" -}}
{{- end -}}
{{- if .Values.config -}}
{{- fail "config overrides are not applied under OpAMP management; change the fleet's rules or profile in Skep instead" -}}
{{- end -}}
{{- else if not (.Files.Get (include "skep-collector.configFile" .)) -}}
{{- fail (printf "no embedded configuration %s" (include "skep-collector.configFile" .)) -}}
{{- end -}}
{{- end -}}
