# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository implements a complete observability stack for OpenShift using GitOps (ArgoCD). It configures logging (Loki), distributed tracing (Tempo), monitoring (Prometheus/Grafana), network observability, service mesh, and alerting infrastructure on OpenShift clusters.

## Prerequisites

Before running any commands:
1. Log in to OpenShift cluster with `oc login`
2. AWS CLI must be installed for S3 bucket creation
3. Set AWS credentials in `aws-env-vars` file (format: `export AWS_ACCESS_KEY_ID=...`)
4. Optionally set Gmail credentials in `gmail-app-vars` for alerting

## Common Commands

### Initial Installation

```bash
# Install GitOps operator and ArgoCD instance
./install-gitops.sh

# Deploy complete observability stack
./install.sh
```

The `install.sh` script:
- Labels worker nodes as infra nodes
- Creates S3 buckets for Loki, Tempo, and Network Observability
- Creates Kubernetes secrets for S3 bucket access
- Creates ConsoleLinks for Grafana and Jaeger UI
- Triggers ArgoCD application deployment via `oc apply -k ./gitops/argocd`

### Manual AWS S3 Bucket Creation

```bash
# Create individual S3 bucket
./prerequisites/aws-s3-bucket.sh <bucket-name>
```

### GitOps Management

```bash
# Apply ArgoCD application manifests (triggers all deployments)
oc apply -k ./gitops/argocd

# View all ArgoCD applications
oc get applications -n openshift-gitops
```

### Common OpenShift Operations

```bash
# Check operator installation status
oc get operators

# View logs from logging stack
oc logs -n openshift-logging <pod-name>

# Check LokiStack status
oc get lokistack -n openshift-logging

# Check TempoStack status
oc get tempostack -n openshift-tempo

# View Grafana route
oc get route -n grafana
```

## Architecture

### GitOps Structure

The repository uses an **App of Apps** pattern with ArgoCD:

- **Root**: `gitops/argocd/kustomization.yaml` - Declares all ArgoCD applications
- **Applications**: Each YAML in `gitops/argocd/application-*.yaml` points to a subdirectory in `gitops/cluster-services/`
- **Sync Policy**: All applications use non-automated sync by default (prune: false, selfHeal: false)

### Cluster Services Organization

Each observability component is under `gitops/cluster-services/` with numbered subdirectories indicating installation order:

**ocp-logging/**
- `01-clo-operator/` - Cluster Logging Operator
- `02-loki-operator/` - Loki Operator
- `03-cluster-logging/` - ClusterRoleBindings, ServiceAccounts, ClusterLogForwarder
- `04-loki/` - LokiStack CR (references S3 secret `s3-bucket-loki`)

**ocp-dist-tracing/**
- `01-tempo-operator/` - Tempo Operator
- `02-opentelemetry-operator/` - OpenTelemetry Operator
- `03-otel/` - OpenTelemetryCollector, ServiceAccounts, ClusterRoleBindings
- `04-tempo/` - TempoStack CR (references S3 secret `s3-bucket-tempo`)

**grafana/**
- `01-operator/` - Grafana Operator
- `02-grafana/` - Grafana instance with OAuth proxy
- `03-datasource/` - Grafana datasources (Prometheus, Loki, Tempo)
- `04-dashboard/` - Pre-configured dashboards
- `05-grafana-tempo/` - Tempo-specific dashboards

**ocp-monitoring/** - Prometheus configuration (ClusterMonitoring, UserWorkloadMonitoring)

**ocp-cluster-observability/** - Cluster Observability Operator with UI plugins

**ocp-network-observability/** - Network flow monitoring (references S3 secret `s3-bucket-net-obs`)

**ocp-servicemesh3/** - Service mesh v3 installation

**ocp-alerting/** - AlertManager configuration

### Infrastructure Scheduling

All observability components are configured with tolerations for infra nodes:
```yaml
tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/infra
    value: reserved
  - effect: NoExecute
    key: node-role.kubernetes.io/infra
    value: reserved
```

Worker nodes are labeled as infra nodes by `install.sh` (line 66-69).

### S3 Storage Pattern

Three S3 buckets are created with random suffixes:
1. **Loki** (`s3-bucket-loki-xxxxx`) - Log storage in `openshift-logging` namespace
2. **Network Observability** (`s3-bucket-net-obs-xxxxx`) - Flow data in `netobserv` namespace
3. **Tempo** (`s3-bucket-tempo-xxxxx`) - Trace storage in `openshift-tempo` namespace

Secrets are created using OpenShift templates in `prerequisites/aws-s3-secret-*.yaml` with `oc process`.

### Application Deployments

Sample applications are in `gitops/applications/`:
- **quarkus-observability-app** - Quarkus application with observability instrumentation
- **bookinfo** - Service mesh demo application

### Secret Management

Secrets are created using `oc process` with parameter files:
```bash
oc process -f prerequisites/aws-s3-secret-loki.yaml \
    --param-file aws-env-vars \
    -p SECRET_NAMESPACE=openshift-logging \
    -p AWS_S3_BUCKET=$LOKI_BUCKET | oc apply -f -
```

### ConsoleLinks

The installation creates OpenShift ConsoleLinks for easy access:
- Grafana UI
- Jaeger UI (Tempo gateway)

Route suffix is dynamically extracted: `install.sh:165`

## Important Configuration Details

- **Storage Class**: LokiStack uses `gp3-csi` by default (line 39 in lokistack YAML). Can be changed to ODF with `ocs-storagecluster-ceph-rbd`.
- **Retention**: Loki retention set to 7 days globally
- **LokiStack Size**: `1x.demo` (minimal deployment, suitable for testing)
- **ArgoCD Annotations**: Some resources use `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` for CRDs
- **GitHub Repository**: All ArgoCD applications reference `https://github.com/anmiralles/openshift-observability-workshop.git` on `main` branch

## Installation Flow

1. Run `install-gitops.sh` to deploy ArgoCD
2. Run `install.sh` which:
   - Creates S3 buckets and secrets
   - Applies `oc apply -k ./gitops/argocd` to create ArgoCD applications
3. ArgoCD deploys all components in dependency order based on kustomization structure

## Modifying the Stack

When adding new components:
1. Create directory under `gitops/cluster-services/<component-name>/`
2. Use numbered subdirectories (01-, 02-, etc.) for installation phases
3. Add kustomization.yaml referencing all resources
4. Create ArgoCD Application in `gitops/argocd/application-<name>.yaml`
5. Add application reference to `gitops/argocd/kustomization.yaml`

When modifying existing resources, ArgoCD will detect changes automatically but won't sync unless `selfHeal: true` is set.