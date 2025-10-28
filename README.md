# OpenShift Observability Workshop

A comprehensive observability stack for OpenShift Container Platform using GitOps (ArgoCD) for deployment and management. This workshop demonstrates a complete end-to-end observability solution including logging, distributed tracing, monitoring, network observability, and service mesh.

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Observability Stack Components](#observability-stack-components)
- [GitOps Structure](#gitops-structure)
- [Post-Installation](#post-installation)
- [Common Operations](#common-operations)

## Architecture

This repository implements an **App of Apps** pattern using ArgoCD, where a root application manages multiple child applications. Each component of the observability stack is deployed as a separate ArgoCD application, ensuring modular and declarative infrastructure management.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ArgoCD (GitOps)                      │
│                     App of Apps                         │
└────────────────────┬────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
┌───────▼──────┐ ┌──▼────────┐ ┌▼──────────────┐
│   Logging    │ │  Tracing  │ │  Monitoring   │
│  (Loki)      │ │  (Tempo)  │ │ (Prometheus)  │
└──────────────┘ └───────────┘ └───────────────┘
        │            │            │
        └────────────┼────────────┘
                     │
            ┌────────▼─────────┐
            │     Grafana      │
            │  (Visualization) │
            └──────────────────┘
```

### Infrastructure Scheduling

All observability components are configured to run on infrastructure nodes with appropriate tolerations:

```yaml
tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/infra
    value: reserved
  - effect: NoExecute
    key: node-role.kubernetes.io/infra
    value: reserved
```

## Prerequisites

Before running the installation scripts, ensure you have:

1. **OpenShift Cluster Access**
   ```bash
   oc login --token=<your-token> --server=<your-server>
   ```

2. **AWS CLI** (for S3 bucket creation)
   ```bash
   aws --version
   ```

3. **AWS Credentials File** - Create `aws-env-vars` file in the root directory:
   ```bash
   export AWS_ACCESS_KEY_ID=your-access-key
   export AWS_SECRET_ACCESS_KEY=your-secret-key
   export AWS_REGION=us-east-1
   ```

4. **Gmail App Credentials** (Optional - for alerting) - Create `gmail-app-vars` file:
   ```bash
   export GMAIL_ACCOUNT=your-email@gmail.com
   export GMAIL_AUTH_TOKEN=your-app-password
   ```

## Quick Start

### Step 1: Install GitOps Operator and ArgoCD

```bash
./install-gitops.sh
```

This script:
- Installs the OpenShift GitOps operator
- Deploys an ArgoCD instance in the `openshift-gitops` namespace
- Creates a ConsoleLink for easy ArgoCD UI access

### Step 2: Deploy Observability Stack

```bash
./install-observability.sh
```

This script:
- Labels worker nodes as infrastructure nodes
- Creates S3 buckets for Loki, Tempo, and Network Observability
- Creates Kubernetes secrets for S3 access
- Creates ConsoleLinks for Grafana and Jaeger UI
- Triggers ArgoCD to deploy all observability components

## Observability Stack Components

The observability stack is organized under `gitops/cluster-services/` with the following components:

### 1. Logging Stack (`ocp-logging/`)

Complete logging solution using the Cluster Logging Operator and Loki.

**Components:**
- **01-clo-operator/** - Cluster Logging Operator for managing log collection
- **02-loki-operator/** - Loki Operator for log aggregation backend
- **03-cluster-logging/** - Log forwarding configuration and RBAC
  - `ClusterLogForwarder` - Routes logs from different sources (application, infrastructure, audit)
  - ServiceAccounts and ClusterRoleBindings for log collection
  - Log File Metrics Exporter (LFME) for exposing log metrics
- **04-loki/** - LokiStack instance
  - Storage: S3-backed (`s3-bucket-loki` secret)
  - Size: `1x.demo` (minimal deployment for testing)
  - Retention: 7 days global retention
  - Storage Class: `gp3-csi` (can be changed to ODF)

**Features:**
- Collects application, infrastructure, and audit logs
- Stores logs in S3 for durability
- Integrates with Grafana for visualization
- Supports log querying via LogQL

### 2. Distributed Tracing (`ocp-dist-tracing/`)

End-to-end distributed tracing using Tempo and OpenTelemetry.

**Components:**
- **01-tempo-operator/** - Tempo Operator for trace storage backend
- **02-opentelemetry-operator/** - OpenTelemetry Operator for trace collection
- **03-otel/** - OpenTelemetry Collector configuration
  - Collector instance for receiving traces
  - RBAC for trace writing (dev and prod tenants)
  - ServiceAccounts and ClusterRoleBindings
- **04-tempo/** - TempoStack instance
  - Storage: S3-backed (`s3-bucket-tempo` secret)
  - Multi-tenant support (dev and prod)
  - Jaeger Query UI for trace visualization
  - RBAC for trace reading

**Features:**
- Distributed tracing across microservices
- OpenTelemetry-based instrumentation
- Jaeger UI integration
- S3 storage for trace data
- Multi-tenancy support

### 3. Monitoring (`ocp-monitoring/`)

Built-in OpenShift monitoring using Prometheus.

**Components:**
- `cm-cluster-monitoring-config.yaml` - Cluster monitoring configuration
- `cm-user-workload-monitoring-config.yaml` - User workload monitoring
- `secret-alertmanager-main.yaml` - AlertManager configuration

**Features:**
- Prometheus for metrics collection
- User workload monitoring enabled
- Integration with Grafana
- AlertManager for alert routing

### 4. Grafana (`grafana/`)

Unified visualization platform for metrics, logs, and traces.

**Components:**
- **01-operator/** - Grafana Operator installation
- **02-grafana/** - Grafana instance with OAuth proxy
  - OAuth integration with OpenShift
  - ClusterRoleBindings for cluster monitoring access
  - TLS certificate injection
- **03-datasource/** - Preconfigured datasources
  - Prometheus (metrics)
  - Loki (logs)
  - Tempo (traces)
- **04-dashboard/** - Custom dashboards
  - Quarkus Observability dashboard
- **05-grafana-tempo/** - Tempo operational dashboards
  - Tempo Operational
  - Tempo Reads/Writes
  - Tempo Resources
  - Tempo Rollout Progress
  - Tempo Tenants

**Features:**
- Single pane of glass for all observability data
- OpenShift OAuth integration
- Pre-configured datasources
- Custom and operational dashboards
- Correlation between metrics, logs, and traces

### 5. Cluster Observability (`ocp-cluster-observability/`)

Enhanced OpenShift Console UI plugins for observability.

**Components:**
- **01-operator/** - Cluster Observability Operator
- **02-uiplugins/** - Console UI plugins
  - Distributed Tracing plugin
  - Logging plugin
  - Monitoring plugin
  - Troubleshooting Panel plugin

**Features:**
- Native OpenShift Console integration
- Enhanced troubleshooting capabilities
- Unified observability experience

### 6. Network Observability (`ocp-network-observability/`)

Network flow monitoring and analysis using eBPF.

**Components:**
- `FlowCollector` - Network flow collection configuration
- Kafka integration for flow data streaming
- LokiStack integration for flow storage
- S3 storage backend (`s3-bucket-net-obs` secret)

**Features:**
- eBPF-based network flow collection
- Network topology visualization
- Flow data analysis
- S3 storage for historical data
- Integration with OpenShift Console

### 7. Service Mesh v3 (`ocp-servicemesh3/`)

Istio-based service mesh for microservices communication.

**Components:**
- **01-servicemesh-operator/** - Service Mesh Operator subscription
- **02-servicemesh/** - Istio control plane and data plane
  - Istio control plane (`Istio` CR)
  - Istio CNI (`IstioCNI` CR)
  - Ingress Gateway (`IstioIngressGateway` CR)
  - Telemetry configuration (`IstioTelemetry` CR)
  - ServiceMonitor and PodMonitor for metrics
- **03-kiali-operator/** - Kiali Operator for service mesh visualization
- **04-Kiali/** - Kiali instance with OSSMC integration

**Features:**
- Traffic management and routing
- mTLS encryption between services
- Observability (metrics, logs, traces)
- Kiali dashboard for service mesh visualization
- Integration with Prometheus and Grafana

### 8. Alerting (`ocp-alerting/`)

Alert routing and notification configuration.

**Components:**
- `alertmanagerconfig-alert-routing-to-mail.yaml` - Email alert routing
- `alertmanagerconfig-alert-routing-to-mail-label.yaml` - Label-based routing

**Features:**
- Gmail integration for alert notifications
- Label-based alert routing
- Integration with AlertManager

## GitOps Structure

### App of Apps Pattern

The root kustomization at `gitops/argocd/kustomization.yaml` declares all ArgoCD applications:

```yaml
resources:
  - application-ocp-monitoring.yaml
  - application-ocp-logging.yaml
  - application-ocp-coo.yaml
  - application-ocp-dist-tracing.yaml
  - application-ocp-servicemesh.yaml
  - application-grafana.yaml
  - application-ocp-alerting.yaml
  - application-ocp-network-obs.yaml
  - application-quarkus-observability.yaml
  - application-bookinfo.yaml
```

### Application Structure

Each ArgoCD application follows this pattern:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <component-name>
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/anmiralles/openshift-observability-workshop.git
    targetRevision: main
    path: gitops/cluster-services/<component-name>
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
```

### Sync Policy

- **Automated**: Disabled by default (manual sync required)
- **Prune**: Disabled (resources are not automatically deleted)
- **SelfHeal**: Disabled (changes are not automatically reverted)

This conservative approach ensures changes are reviewed before being applied to the cluster.

## Post-Installation

### Access the UIs

After installation, access the following web interfaces:

1. **ArgoCD**
   ```bash
   oc get route argocd-server -n openshift-gitops
   ```
   Login: Use OpenShift credentials

2. **Grafana**
   ```bash
   oc get route grafana-route -n grafana
   ```
   Login: Use OpenShift OAuth

3. **Jaeger UI** (Tempo)
   ```bash
   oc get route tempo-tempostack-gateway -n openshift-tempo
   ```

4. **Kiali** (Service Mesh)
   ```bash
   oc get route kiali -n istio-system
   ```

### Verify Component Status

```bash
# Check ArgoCD applications
oc get applications -n openshift-gitops

# Check LokiStack
oc get lokistack -n openshift-logging

# Check TempoStack
oc get tempostack -n openshift-tempo

# Check Grafana
oc get grafana -n grafana

# Check all operators
oc get operators
```

### View ConsoleLinks

ConsoleLinks are created for easy access from the OpenShift Console:

```bash
oc get consolelinks
```

## Common Operations

### Sync ArgoCD Applications

```bash
# Sync all applications (from repository root)
oc apply -k ./gitops/argocd

# Sync specific application using ArgoCD CLI
argocd app sync application-ocp-logging

# Sync via OpenShift CLI
oc patch application application-ocp-logging -n openshift-gitops \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

### View Logs

```bash
# View logs from a specific pod
oc logs -n openshift-logging <pod-name>

# View logs from Cluster Logging Operator
oc logs -n openshift-logging deployment/cluster-logging-operator

# View logs from Vector (log collector)
oc logs -n openshift-logging daemonset/collector
```

### Check Storage

```bash
# Check S3 secrets
oc get secret s3-bucket-loki -n openshift-logging
oc get secret s3-bucket-tempo -n openshift-tempo
oc get secret s3-bucket-net-obs -n netobserv

# View bucket configuration
oc get secret s3-bucket-loki -n openshift-logging -o yaml
```

### Troubleshooting

```bash
# Check operator status
oc get csv -n openshift-logging
oc get csv -n openshift-tempo-operator

# Check pod status
oc get pods -n openshift-logging
oc get pods -n openshift-tempo
oc get pods -n grafana

# Check events
oc get events -n openshift-logging --sort-by='.lastTimestamp'

# Check ArgoCD application health
oc get application application-ocp-logging -n openshift-gitops -o yaml
```

## Sample Applications

The repository includes two sample applications for testing observability:

1. **Quarkus Observability App** (`gitops/applications/quarkus-observability-app/`)
   - Instrumented Quarkus application
   - Demonstrates metrics, logs, and traces integration

2. **Bookinfo** (`gitops/applications/bookinfo/`)
   - Classic microservices demo application
   - Service mesh demonstration
   - Multi-service tracing example

## Storage Configuration

### S3 Buckets

Three S3 buckets are created with random suffixes:

1. **Loki**: `s3-bucket-loki-xxxxx` (logs)
2. **Tempo**: `s3-bucket-tempo-xxxxx` (traces)
3. **Network Observability**: `s3-bucket-net-obs-xxxxx` (network flows)

### Alternative Storage (ODF)

For on-premise deployments without S3, you can use OpenShift Data Foundation (ODF):

- Uncomment ODF-related resources in the kustomization files
- Update storage class to `ocs-storagecluster-ceph-rbd`
- Use ObjectBucketClaims (OBC) instead of S3 secrets

## Customization

### Modifying Components

1. Edit resources in `gitops/cluster-services/<component>/`
2. Commit changes to git repository
3. Sync ArgoCD application to apply changes

### Adding New Components

1. Create directory under `gitops/cluster-services/<new-component>/`
2. Use numbered subdirectories for installation phases (01-, 02-, etc.)
3. Create `kustomization.yaml` referencing all resources
4. Create ArgoCD application in `gitops/argocd/application-<name>.yaml`
5. Add application reference to `gitops/argocd/kustomization.yaml`
6. Apply changes: `oc apply -k ./gitops/argocd`

### Retention Policies

Modify retention settings in component configurations:

- **Loki**: Edit `lokistack-logging-loki.yaml` (default: 7 days)
- **Tempo**: Edit `tempostack.yaml` retention settings
- **Prometheus**: Edit `cm-cluster-monitoring-config.yaml`

## Architecture Decisions

### Why This Stack?

- **Loki**: Cost-effective log aggregation with label-based indexing
- **Tempo**: Scalable distributed tracing without expensive indexing
- **Grafana**: Unified visualization reducing context switching
- **Prometheus**: Industry-standard metrics collection
- **OpenTelemetry**: Vendor-neutral instrumentation standard
- **Istio**: Mature service mesh with strong observability features
- **ArgoCD**: GitOps-native continuous delivery for Kubernetes

### GitOps Benefits

- Declarative infrastructure as code
- Version control for all configuration
- Audit trail of all changes
- Easy rollback capabilities
- Consistent deployments across environments

## Contributing

When contributing to this repository:

1. Test changes in a development cluster first
2. Ensure all ArgoCD applications sync successfully
3. Update documentation for any architectural changes
4. Follow the numbered directory pattern for installation order

## Resources

- [OpenShift GitOps Documentation](https://docs.openshift.com/gitops/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## License

This project is for workshop and educational purposes.