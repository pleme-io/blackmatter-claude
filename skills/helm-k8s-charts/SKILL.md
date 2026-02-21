---
name: helm-k8s-charts
description: Creates Helm 4 charts for Kubernetes services following modern best practices. Use when creating new Helm charts, converting Kustomize manifests to Helm, adding chart templating, or packaging any Kubernetes workload (Deployment, StatefulSet, CronJob, operator, database) as a reusable Helm chart. Covers chart scaffolding, library charts, values schema, OCI registry publishing, and FluxCD HelmRelease integration.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
metadata:
  version: "1.0.0"
  last_verified: "2026-02-21"
  helm_version: "4.1"
  chart_api_version: "v2"
  domain_keywords:
    - "helm"
    - "chart"
    - "kubernetes"
    - "k8s"
    - "deployment"
    - "statefulset"
    - "kustomize to helm"
    - "packaging"
---

# Helm 4 Kubernetes Chart Patterns

## Pre-Flight

Before creating any chart:

1. **Identify the workload type** — Deployment, StatefulSet, Job, CronJob, DaemonSet, or operator
2. **Check for existing manifests** — Look in `k8s/` repo for Kustomize bases to convert
3. **Determine chart scope** — Single service chart vs umbrella chart vs library chart
4. **Confirm Helm 4 is available** — `helm version` should show v4.x

## Chart Directory Layout

```
charts/{chart-name}/
  Chart.yaml              # Required — metadata, dependencies, type
  values.yaml             # Default configuration (documented, camelCase)
  values.schema.json      # JSON Schema for values validation
  templates/
    _helpers.tpl          # Reusable named templates
    deployment.yaml       # Or statefulset.yaml, job.yaml, etc.
    service.yaml
    serviceaccount.yaml
    configmap.yaml
    secret.yaml           # Only structure — values from Secret refs
    hpa.yaml              # Optional — HorizontalPodAutoscaler
    pdb.yaml              # Optional — PodDisruptionBudget
    networkpolicy.yaml    # Optional — NetworkPolicy
    servicemonitor.yaml   # Optional — Prometheus ServiceMonitor
    ingress.yaml          # Optional — Ingress/IngressRoute
    NOTES.txt             # Post-install usage instructions
  crds/                   # Plain YAML only (no templates), installed once
```

## Chart.yaml Template

```yaml
apiVersion: v2
name: {chart-name}
description: {one-sentence description}
type: application
version: 0.1.0
appVersion: "1.0.0"
kubeVersion: ">=1.28.0"
maintainers:
  - name: pleme-io
    url: https://github.com/pleme-io
sources:
  - https://github.com/pleme-io/{repo}
keywords:
  - pleme-io
  - {service-category}
annotations:
  artifacthub.io/license: UNLICENSED
```

**Rules:**
- `apiVersion: v2` (Helm 3+/4 charts)
- `type: application` for installable charts, `type: library` for shared helpers
- `version` is the chart version (SemVer), `appVersion` is the app version
- Chart name: lowercase, dashes only, no underscores

## _helpers.tpl Standard Templates

Every chart MUST define these named templates:

```yaml
{{/*
Chart name (truncated to 63 chars for K8s label limits).
*/}}
{{- define "{chart}.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name (release + chart, truncated to 63 chars).
*/}}
{{- define "{chart}.fullname" -}}
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
Standard labels applied to ALL resources.
*/}}
{{- define "{chart}.labels" -}}
helm.sh/chart: {{ include "{chart}.chart" . }}
{{ include "{chart}.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: pleme-io
{{- end }}

{{/*
Selector labels (immutable after creation — used by Deployment .spec.selector).
*/}}
{{- define "{chart}.selectorLabels" -}}
app.kubernetes.io/name: {{ include "{chart}.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Chart label value: name-version (dots replaced with underscores for label safety).
*/}}
{{- define "{chart}.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "{chart}.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "{chart}.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Common annotations (checksum triggers rolling restart on config change).
*/}}
{{- define "{chart}.podAnnotations" -}}
{{- with .Values.podAnnotations }}
{{- toYaml . }}
{{- end }}
{{- if .Values.config }}
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
{{- end }}
{{- end }}
```

Replace `{chart}` with the actual chart name in all `define` calls.

## values.yaml Conventions

```yaml
# -- Number of replicas
replicaCount: 1

# -- Container image configuration
image:
  # -- Image registry
  registry: ghcr.io
  # -- Image repository (without registry prefix)
  repository: pleme-io/{service-name}
  # -- Image tag (defaults to chart appVersion)
  tag: ""
  # -- Image pull policy
  pullPolicy: IfNotPresent

# -- Image pull secrets for private registries
imagePullSecrets: []

# -- Override chart name in resource names
nameOverride: ""
# -- Override full resource name
fullnameOverride: ""

serviceAccount:
  # -- Create a ServiceAccount
  create: true
  # -- Annotations for the ServiceAccount
  annotations: {}
  # -- Override ServiceAccount name
  name: ""

# -- Pod-level annotations
podAnnotations: {}
# -- Pod-level security context
podSecurityContext: {}
# -- Container-level security context
securityContext: {}

service:
  # -- Service type
  type: ClusterIP
  # -- Service port
  port: 8080

# -- Resource requests and limits
resources: {}
  # requests:
  #   cpu: 100m
  #   memory: 128Mi
  # limits:
  #   cpu: 500m
  #   memory: 512Mi

# -- Node selector for pod scheduling
nodeSelector: {}
# -- Tolerations for pod scheduling
tolerations: []
# -- Affinity rules for pod scheduling
affinity: {}

# -- Application-specific configuration (mounted as ConfigMap)
config: {}

# -- Existing secret name for sensitive environment variables
existingSecret: ""

# -- Additional environment variables
extraEnv: []

# -- Additional volume mounts
extraVolumeMounts: []
# -- Additional volumes
extraVolumes: []
```

**Rules:**
- camelCase for all keys
- Comment every field with `# --` prefix (enables helm-docs generation)
- Quote all string defaults
- Use `{}` for empty maps, `[]` for empty lists
- Prefer maps over arrays for `--set` compatibility
- Never set resource limits as defaults (let users decide)
- Image tag defaults to `""` which resolves to `.Chart.AppVersion`

## Workload Templates

### Deployment (most common)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "{chart}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- include "{chart}.podAnnotations" . | nindent 8 }}
      labels:
        {{- include "{chart}.labels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "{chart}.serviceAccountName" . }}
      {{- with .Values.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          {{- with .Values.securityContext }}
          securityContext:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          {{- if .Values.config }}
          envFrom:
            - configMapRef:
                name: {{ include "{chart}.fullname" . }}
          {{- end }}
          {{- if .Values.existingSecret }}
          envFrom:
            {{- if .Values.config }}
            {{- end }}
            - secretRef:
                name: {{ .Values.existingSecret }}
          {{- end }}
          {{- with .Values.extraEnv }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          {{- with .Values.resources }}
          resources:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.extraVolumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.extraVolumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### StatefulSet (databases, message brokers)

Add to values.yaml:

```yaml
persistence:
  enabled: true
  storageClass: ""
  accessMode: ReadWriteOnce
  size: 10Gi
```

Template uses `volumeClaimTemplates` instead of PVC:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
spec:
  serviceName: {{ include "{chart}.fullname" . }}
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "{chart}.selectorLabels" . | nindent 6 }}
  template:
    # ... (same pod template as Deployment)
  {{- if .Values.persistence.enabled }}
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: [{{ .Values.persistence.accessMode | quote }}]
        {{- if .Values.persistence.storageClass }}
        storageClassName: {{ .Values.persistence.storageClass | quote }}
        {{- end }}
        resources:
          requests:
            storage: {{ .Values.persistence.size }}
  {{- end }}
```

### CronJob

Add to values.yaml:

```yaml
schedule: "*/5 * * * *"
successfulJobsHistoryLimit: 3
failedJobsHistoryLimit: 1
concurrencyPolicy: Forbid
```

### Job (one-shot, e.g., migrations)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: {{ .Values.backoffLimit | default 3 }}
  template:
    # ... pod template
```

## Supporting Resources

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "{chart}.selectorLabels" . | nindent 4 }}
```

### ConfigMap (from values.config map)

```yaml
{{- if .Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
data:
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
{{- end }}
```

### ServiceAccount

```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "{chart}.serviceAccountName" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

### NetworkPolicy

```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "{chart}.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}
      ports:
        - port: {{ .Values.service.port }}
          protocol: TCP
  egress:
    - to: []  # Allow all egress by default
{{- end }}
```

### PodDisruptionBudget

```yaml
{{- if .Values.podDisruptionBudget.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
spec:
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "{chart}.selectorLabels" . | nindent 6 }}
{{- end }}
```

### ServiceMonitor (Prometheus)

```yaml
{{- if .Values.metrics.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "{chart}.fullname" . }}
  labels:
    {{- include "{chart}.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "{chart}.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: http
      path: {{ .Values.metrics.path | default "/metrics" }}
      interval: {{ .Values.metrics.serviceMonitor.interval | default "30s" }}
{{- end }}
```

## FluxCD HelmRelease Integration

Charts are consumed via FluxCD HelmRelease in the k8s repo:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: {service-name}
  namespace: {namespace}
spec:
  interval: 5m
  chart:
    spec:
      chart: {chart-name}
      version: ">=0.1.0"
      sourceRef:
        kind: HelmRepository
        name: pleme-io
        namespace: flux-system
      interval: 1m
  values:
    replicaCount: 2
    image:
      tag: "amd64-abc123"
    config:
      DATABASE_URL: "postgresql://..."
    existingSecret: "{service}-secrets"
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        memory: 512Mi
```

## OCI Registry Publishing

Charts are published to GHCR as OCI artifacts:

```bash
# Package
helm package charts/{chart-name}

# Login to GHCR
echo $GITHUB_TOKEN | helm registry login ghcr.io -u pleme-io --password-stdin

# Push
helm push {chart-name}-0.1.0.tgz oci://ghcr.io/pleme-io/charts

# Install from OCI
helm install {release} oci://ghcr.io/pleme-io/charts/{chart-name} --version 0.1.0
```

## Library Chart Pattern

For shared templates across charts, create a library chart:

```yaml
# Chart.yaml
apiVersion: v2
name: pleme-lib
type: library
version: 0.1.0
```

Consumer charts declare it as a dependency:

```yaml
# Chart.yaml
dependencies:
  - name: pleme-lib
    version: "0.1.x"
    repository: "oci://ghcr.io/pleme-io/charts"
```

Then use: `{{ include "pleme-lib.labels" . }}`

## Pleme-io Service Inventory

Services eligible for Helm charts (currently Kustomize):

### Product Services
| Service | Type | Namespace | Priority |
|---------|------|-----------|----------|
| lilitu-backend | Deployment | lilitu-staging | High |
| lilitu-web | Deployment | lilitu-staging | High |
| lilitu-workers | Deployment | lilitu-staging | High |
| lilitu-nats | StatefulSet | lilitu-staging | High |

### Infrastructure Services
| Service | Type | Namespace | Priority |
|---------|------|-----------|----------|
| kenshi | Operator | kenshi-system | High |
| shinka | Operator | shinka-system | High |
| novasearch | StatefulSet | novaskyn-staging | High |
| kanidm | StatefulSet | kanidm | Medium |
| gitea | Deployment | gitea | Medium |
| zot | Deployment | zot | Medium |
| rustfs | StatefulSet | rustfs | Medium |
| mailpit | Deployment | mailpit | Low |
| uptime-kuma | Deployment | uptime-kuma | Low |
| vaultwarden | Deployment | vaultwarden | Low |
| outline | Deployment | outline | Low |
| n8n | Deployment | n8n | Low |
| plausible | Deployment | plausible | Low |
| atuin | Deployment | atuin | Low |
| stalwart | Deployment | stalwart | Low |
| kokoro-tts | Deployment | kokoro-tts | Low |
| linkwarden | Deployment | linkwarden | Low |
| continuwuity | Deployment | continuwuity | Low |
| karakeep | Deployment | karakeep | Low |
| media (rqbit+jellyfin) | Deployment | media | Low |

### Already Helm-Managed (no action needed)
- cloudnative-pg (cnpg-system)
- prometheus-operator
- redis-operator

## Anti-Patterns

- **Never hardcode namespace** in template metadata — use `helm install -n {ns}`
- **Never use `latest` tag** as default — use `""` which falls back to `.Chart.AppVersion`
- **Never put secrets in values.yaml** — use `existingSecret` reference pattern
- **Never template CRD files** — `crds/` directory only accepts plain YAML
- **Never use arrays for `--set`-able config** — use maps instead
- **Never omit resource kind from filename** — `deployment.yaml` not `app.yaml`
- **Never define non-namespaced templates** — always `{chart}.{name}` in `define`
- **Never set default resource limits** — let operators decide via values overrides

## Validation Checklist

Before publishing any chart:

- [ ] `helm lint charts/{name}` passes
- [ ] `helm template charts/{name}` renders valid YAML
- [ ] `helm template charts/{name} | kubectl apply --dry-run=server -f -` validates against cluster
- [ ] `values.schema.json` validates all required fields
- [ ] All labels include `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `helm.sh/chart`
- [ ] Selector labels are a strict subset of pod labels
- [ ] NOTES.txt prints useful post-install instructions
- [ ] Chart version bumped for any template change
