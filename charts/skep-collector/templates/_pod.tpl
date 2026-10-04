{{/* The pod template shared by the agent DaemonSet and the gateway Deployment. */}}
{{- define "skep-collector.podTemplate" -}}
{{- $agent := eq .Values.mode "agent" -}}
metadata:
  labels:
    {{- include "skep-collector.labels" . | nindent 4 }}
    {{- with .Values.podLabels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- if or (not .Values.opamp.enabled) .Values.podAnnotations }}
  annotations:
    {{- if not .Values.opamp.enabled }}
    # Roll the pods when the configuration changes.
    checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    {{- end }}
    {{- with .Values.podAnnotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  {{- end }}
spec:
  serviceAccountName: {{ include "skep-collector.serviceAccountName" . }}
  # Only agents call the Kubernetes API (k8s_attributes).
  automountServiceAccountToken: {{ $agent }}
  {{- with .Values.imagePullSecrets }}
  imagePullSecrets:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.priorityClassName }}
  priorityClassName: {{ . }}
  {{- end }}
  securityContext:
    {{- toYaml .Values.podSecurityContext | nindent 4 }}
  containers:
    - name: otelcol
      image: {{ include "skep-collector.image" . | quote }}
      imagePullPolicy: {{ .Values.image.pullPolicy }}
      {{- if .Values.opamp.enabled }}
      command: ["/opampsupervisor"]
      args: ["--config", "/etc/skep-otelcol/supervisor.yaml"]
      {{- else }}
      args:
        - --config
        - /etc/skep-otelcol/chart/config.yaml
        {{- if .Values.config }}
        - --config
        - /etc/skep-otelcol/chart/overrides.yaml
        {{- end }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.securityContext | nindent 8 }}
      envFrom:
        - secretRef:
            name: {{ include "skep-collector.secretName" . }}
      env:
        - name: GOMEMLIMIT
          value: {{ .Values.goMemLimit | quote }}
        {{- if $agent }}
        - name: K8S_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        {{- else }}
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        {{- end }}
        - name: SKEP_ENDPOINT
          value: {{ .Values.skep.endpoint | toString | quote }}
        - name: SKEP_ENVIRONMENT
          value: {{ .Values.skep.environment | toString | quote }}
        - name: SKEP_COLLECTOR_NAME
          value: {{ include "skep-collector.collectorName" . | quote }}
        - name: SKEP_FLEET
          value: {{ .Values.skep.fleet | toString | quote }}
        - name: SKEP_TIER
          value: {{ include "skep-collector.tier" . | quote }}
        {{- if eq .Values.backend.type "otlp" }}
        - name: SKEP_OTLP_ENDPOINT
          value: {{ .Values.backend.otlpEndpoint | toString | quote }}
        {{- end }}
        {{- if eq .Values.backend.type "gateway" }}
        - name: SKEP_GATEWAY_ENDPOINT
          value: {{ .Values.backend.gatewayEndpoint | toString | quote }}
        {{- end }}
        {{- if .Values.opamp.enabled }}
        - name: SKEP_OPAMP_ENDPOINT
          value: {{ include "skep-collector.opampEndpoint" . | quote }}
        {{- end }}
        {{- with .Values.extraEnv }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      ports:
        - name: otlp-grpc
          containerPort: 4317
          protocol: TCP
          {{- if and $agent .Values.hostPorts }}
          hostPort: 4317
          {{- end }}
        - name: otlp-http
          containerPort: 4318
          protocol: TCP
          {{- if and $agent .Values.hostPorts }}
          hostPort: 4318
          {{- end }}
        - name: health
          containerPort: 13133
          protocol: TCP
      # health_check comes with the configuration; under OpAMP it arrives with
      # the first revision, so only readiness is probed there.
      readinessProbe:
        httpGet:
          path: /
          port: health
      {{- if not .Values.opamp.enabled }}
      livenessProbe:
        httpGet:
          path: /
          port: health
      {{- end }}
      resources:
        {{- toYaml .Values.resources | nindent 8 }}
      volumeMounts:
        {{- if not .Values.opamp.enabled }}
        - name: config
          mountPath: /etc/skep-otelcol/chart
          readOnly: true
        {{- end }}
        - name: state
          mountPath: /var/lib/skep-otelcol
        - name: tmp
          mountPath: /tmp
        {{- if $agent }}
        - name: hostfs
          mountPath: /hostfs
          readOnly: true
          mountPropagation: HostToContainer
        {{- end }}
  volumes:
    {{- if not .Values.opamp.enabled }}
    - name: config
      configMap:
        name: {{ include "skep-collector.fullname" . }}
    {{- end }}
    - name: state
      {{- if .Values.state.volume }}
      {{- toYaml .Values.state.volume | nindent 6 }}
      {{- else }}
      emptyDir:
        {{- with .Values.state.sizeLimit }}
        sizeLimit: {{ . }}
        {{- end }}
      {{- end }}
    - name: tmp
      emptyDir: {}
    {{- if $agent }}
    - name: hostfs
      hostPath:
        path: /
    {{- end }}
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.affinity }}
  affinity:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.tolerations }}
  tolerations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
