# Spacelift Prometheus Monitoring Module

[![Terraform](https://img.shields.io/badge/terraform->=1.0-blue.svg)](https://www.terraform.io/)
[![OpenTofu](https://img.shields.io/badge/opentofu->=1.0-orange.svg)](https://opentofu.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This OpenTofu/Terraform module deploys a comprehensive monitoring solution for Spacelift on Google Kubernetes Engine (GKE). It includes Prometheus, Grafana, and the Spacelift Prometheus exporter to provide complete observability for your Spacelift infrastructure.

## Features

- **🚀 Complete Monitoring Stack**: Prometheus, Grafana, and Spacelift exporter deployment
- **🔒 Security-First**: Pod security policies, network policies, and least privilege access
- **💰 Cost Optimized**: Resource limits, storage optimization, and cost monitoring
- **📊 Pre-configured Dashboards**: Kubernetes and Spacelift monitoring dashboards
- **🔍 Service Discovery**: Automatic Prometheus scraping configuration
- **🛡️ Production Ready**: High availability, backup, and disaster recovery support
- **🏗️ Modular Design**: Enable/disable components based on requirements
- **🌐 Multi-Environment**: Support for dev, staging, and production deployments

## Architecture

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│     Spacelift       │    │     Prometheus      │    │      Grafana        │
│     API             │◄───┤     Server          │◄───┤     Dashboard       │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
           ▲                           ▲                           ▲
           │                           │                           │
           │                           │                           │
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Spacelift         │    │   ServiceMonitor    │    │    Ingress          │
│   Exporter          │    │   (Auto-discovery)  │    │    Controller       │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
           │                           │                           │
           └───────────────────────────┼───────────────────────────┘
                                       │
                          ┌─────────────────────┐
                          │    GKE Cluster      │
                          │    (Your existing)  │
                          └─────────────────────┘
```

## Quick Start

### Prerequisites

- Existing GKE cluster
- Spacelift account with API access
- OpenTofu/Terraform >= 1.0
- Kubernetes provider configured

### Basic Usage

```hcl
module "spacelift_monitoring" {
  source = "./modules/spacelift-prometheus-monitoring"
  
  # GCP Configuration
  project_id           = "your-gcp-project"
  gke_cluster_name     = "your-gke-cluster"
  gke_cluster_location = "us-central1"
  
  # Spacelift Configuration
  spacelift_api_endpoint   = "https://your-account.app.spacelift.io"
  spacelift_api_key_id     = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  
  # Environment
  environment = "prod"
  
  tags = {
    Environment = "production"
    Team        = "platform"
    Purpose     = "monitoring"
  }
}
```

### Advanced Configuration

```hcl
module "spacelift_monitoring" {
  source = "./modules/spacelift-prometheus-monitoring"
  
  # GCP Configuration
  project_id           = "your-gcp-project"
  gke_cluster_name     = "your-gke-cluster"
  gke_cluster_location = "us-central1"
  
  # Spacelift Configuration
  spacelift_api_endpoint   = "https://your-account.app.spacelift.io"
  spacelift_api_key_id     = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  
  # Component Configuration
  enable_prometheus        = true
  enable_spacelift_exporter = true
  enable_ingress           = true
  enable_network_policy    = true
  
  # Storage Configuration
  storage_class            = "standard-rwo"
  prometheus_storage_size  = "100Gi"
  grafana_storage_size     = "20Gi"
  prometheus_retention_days = 90
  
  # Ingress Configuration
  domain_name      = "monitoring.yourdomain.com"
  enable_ssl       = true
  ssl_cert_issuer  = "letsencrypt-prod"
  
  # Resource Configuration
  spacelift_exporter_replicas = 2
  spacelift_exporter_resources = {
    requests = {
      cpu    = "200m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
  
  # Cost Optimization
  enable_cost_optimization = true
  cost_optimization_config = {
    enable_vertical_pod_autoscaling = true
    enable_resource_quotas          = true
    enable_limit_ranges            = true
    enable_pod_disruption_budgets  = true
  }
  
  # Backup Configuration
  enable_backup = true
  backup_config = {
    schedule           = "0 2 * * *"
    retention_days     = 30
    gcs_bucket_name   = "monitoring-backups-bucket"
    backup_encryption = true
  }
  
  # Security Configuration
  enable_workload_identity = true
  gcp_service_account_email = "monitoring@your-project.iam.gserviceaccount.com"
  
  # Alerting Configuration
  enable_alerts = true
  alert_manager_config = {
    slack_webhook_url = var.slack_webhook_url
    email_recipients  = ["platform-team@company.com"]
    pagerduty_key    = var.pagerduty_key
  }
  
  # Environment and Tags
  environment = "prod"
  tags = {
    Environment = "production"
    Team        = "platform"
    Purpose     = "monitoring"
    CostCenter  = "engineering"
  }
}
```

## Spacelift Configuration

This module is designed to work seamlessly with Spacelift. Add it to your Spacelift module registry:

### Module Registry Setup

1. **Create Module Entry**: Add this module to your Spacelift module registry
2. **Version Management**: Use semantic versioning (e.g., v1.0.0)
3. **Stack Configuration**: Reference the module in your monitoring stack

### Example Spacelift Stack

```hcl
# spacelift-monitoring-stack.tf
module "monitoring" {
  source  = "spacelift.io/your-org/spacelift-prometheus-monitoring"
  version = "~> 1.0"
  
  project_id           = var.project_id
  gke_cluster_name     = var.gke_cluster_name
  gke_cluster_location = var.gke_cluster_location
  
  spacelift_api_endpoint   = var.spacelift_api_endpoint
  spacelift_api_key_id     = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  
  environment = var.environment
}
```

### Spacelift Stack Variables

Set these as Spacelift environment variables:

- `TF_VAR_spacelift_api_key_id` (marked as sensitive)
- `TF_VAR_spacelift_api_key_secret` (marked as sensitive)
- `TF_VAR_project_id`
- `TF_VAR_gke_cluster_name`
- `TF_VAR_gke_cluster_location`

## Monitoring and Metrics

### Spacelift Metrics

The exporter provides the following metrics:

| Metric | Description | Labels |
|--------|-------------|--------|
| `spacelift_public_worker_pool_runs_pending` | Runs waiting for public workers | - |
| `spacelift_public_worker_pool_workers_busy` | Busy public workers | - |
| `spacelift_worker_pool_runs_pending` | Runs waiting for specific pool | `worker_pool_id`, `worker_pool_name` |
| `spacelift_worker_pool_workers` | Total workers in pool | `worker_pool_id`, `worker_pool_name` |
| `spacelift_current_stacks_count_by_state` | Stack count by state | `state` |
| `spacelift_current_billing_period_used_seats` | Used seats in billing period | - |
| `spacelift_current_average_run_duration` | Average run duration | - |

### Prometheus Configuration

- **Scrape Interval**: 30s (configurable)
- **Retention**: 30 days (configurable)
- **Storage**: 50Gi (configurable)
- **High Availability**: Optional multi-replica setup

### Grafana Dashboards

- **Spacelift Overview**: Main dashboard for Spacelift metrics
- **Kubernetes Cluster**: GKE cluster monitoring
- **Resource Usage**: CPU, memory, and storage utilization
- **Cost Analysis**: Resource cost breakdown

## Security

### Security Features

- **Pod Security Policies**: Enforce security constraints
- **Network Policies**: Isolate monitoring namespace
- **RBAC**: Least privilege service accounts
- **Secret Management**: Kubernetes secrets for API keys
- **Workload Identity**: GCP service account integration
- **Read-only Root Filesystem**: Immutable containers
- **Non-root User**: Containers run as non-root user

### Security Best Practices

1. **API Keys**: Use dedicated Spacelift API keys with minimal permissions
2. **Network Isolation**: Enable network policies
3. **TLS**: Enable SSL/TLS for all external endpoints
4. **Regular Updates**: Keep container images updated
5. **Monitoring**: Monitor for security events and anomalies

## Cost Optimization

### Built-in Cost Features

- **Resource Limits**: Prevent resource sprawl
- **Storage Optimization**: Lifecycle policies for data
- **Vertical Pod Autoscaling**: Right-size containers
- **Resource Quotas**: Namespace-level limits
- **Budget Alerts**: GCP cost monitoring integration

### Cost Estimation

| Component | vCPU | Memory | Storage | Est. Monthly Cost |
|-----------|------|--------|---------|-------------------|
| Prometheus | 0.5-1.0 | 2-4Gi | 50Gi | $15-30 |
| Grafana | 0.25-0.5 | 512Mi-1Gi | 10Gi | $8-15 |
| Spacelift Exporter | 0.1-0.2 | 128-256Mi | - | $2-5 |
| **Total** | **0.85-1.7** | **~3-5Gi** | **60Gi** | **$25-50** |

*Costs vary by region and instance type*

## Troubleshooting

### Common Issues

1. **Spacelift Exporter Connection Failed**
   ```bash
   # Check API credentials
   kubectl get secret spacelift-api-credentials -n spacelift-monitoring -o yaml
   
   # Check exporter logs
   kubectl logs -l app.kubernetes.io/name=spacelift-exporter -n spacelift-monitoring
   ```

2. **Prometheus Not Scraping Metrics**
   ```bash
   # Check ServiceMonitor
   kubectl get servicemonitor spacelift-exporter -n spacelift-monitoring
   
   # Check Prometheus targets
   # Access Prometheus UI and check Status > Targets
   ```

3. **Grafana Dashboard Not Loading**
   ```bash
   # Check Grafana datasource
   kubectl logs -l app.kubernetes.io/name=grafana -n spacelift-monitoring
   
   # Check Grafana configuration
   kubectl get configmap prometheus-grafana -n spacelift-monitoring -o yaml
   ```

4. **Storage Issues**
   ```bash
   # Check PVC status
   kubectl get pvc -n spacelift-monitoring
   
   # Check storage class
   kubectl get storageclass
   ```

### Debugging Commands

```bash
# Check all monitoring resources
kubectl get all -n spacelift-monitoring

# Check events
kubectl get events -n spacelift-monitoring --sort-by='.lastTimestamp'

# Port forward to access services locally
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n spacelift-monitoring
kubectl port-forward svc/prometheus-grafana 3000:80 -n spacelift-monitoring
kubectl port-forward svc/spacelift-exporter 9953:9953 -n spacelift-monitoring

# Check metrics endpoint
curl http://localhost:9953/metrics
```

## Backup and Disaster Recovery

### Backup Strategy

The module supports automated backups when `enable_backup = true`:

- **Prometheus Data**: Daily snapshots to GCS
- **Grafana Dashboards**: Configuration backup
- **Kubernetes Manifests**: State backup
- **Retention**: Configurable retention period

### Disaster Recovery

1. **Data Recovery**
   ```bash
   # Restore from GCS backup
   gsutil cp gs://your-backup-bucket/prometheus-backup-YYYY-MM-DD.tar.gz .
   
   # Apply to new cluster
   kubectl apply -f backup-manifests/
   ```

2. **Cross-Region Setup**
   ```hcl
   # Deploy in multiple regions
   module "monitoring_primary" {
     source = "./modules/spacelift-prometheus-monitoring"
     gke_cluster_location = "us-central1"
     # ... other config
   }
   
   module "monitoring_secondary" {
     source = "./modules/spacelift-prometheus-monitoring"
     gke_cluster_location = "us-east1"
     # ... other config
   }
   ```

## Monitoring the Monitoring

### Health Checks

The module includes comprehensive health monitoring:

- **Liveness Probes**: Ensure containers are healthy
- **Readiness Probes**: Ensure services are ready
- **Service Monitors**: Prometheus self-monitoring
- **Custom Alerts**: Alert on monitoring failures

### Key Alerts

```yaml
# Example alert rules included
- alert: PrometheusDown
  expr: up{job="prometheus"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Prometheus server is down"

- alert: SpaceliftExporterDown
  expr: up{job="spacelift-exporter"} == 0
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "Spacelift exporter is unreachable"

- alert: HighSpaceliftRunQueue
  expr: spacelift_public_worker_pool_runs_pending > 10
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High number of pending Spacelift runs"
```

## Performance Tuning

### Optimization Guidelines

1. **Prometheus Optimization**
   ```yaml
   # Adjust scrape intervals based on needs
   prometheus_scrape_interval: "60s"  # Reduce for less critical metrics
   
   # Optimize retention vs storage
   prometheus_retention_days: 15      # Reduce for cost savings
   prometheus_storage_size: "30Gi"    # Adjust based on retention
   ```

2. **Resource Tuning**
   ```hcl
   spacelift_exporter_resources = {
     requests = {
       cpu    = "50m"   # Start small
       memory = "64Mi"  # Monitor actual usage
     }
     limits = {
       cpu    = "200m"  # Set reasonable limits
       memory = "128Mi"
     }
   }
   ```

3. **High Traffic Scenarios**
   ```hcl
   # Scale for high-traffic Spacelift accounts
   spacelift_exporter_replicas = 3
   prometheus_storage_size = "200Gi"
   prometheus_retention_days = 90
   ```

## Contributing

### Development Setup

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd spacelift-prometheus-monitoring
   ```

2. **Install Dependencies**
   ```bash
   # Install OpenTofu/Terraform
   # Install kubectl
   # Install helm
   ```

3. **Test Changes**
   ```bash
   # Validate syntax
   tofu validate
   
   # Plan changes
   tofu plan -var-file="examples/basic/terraform.tfvars"
   
   # Test locally
   tofu apply -target=kubernetes_namespace.monitoring
   ```

### Module Structure

```
.
├── main.tf                     # Main module configuration
├── variables.tf                # Input variables
├── outputs.tf                  # Module outputs
├── versions.tf                 # Provider requirements
├── helm-values/
│   └── prometheus.yaml         # Prometheus Helm values template
├── examples/
│   ├── basic/                  # Basic usage example
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
.

## Changelog

### v1.0.0 (Latest)
- Initial release
- Full Prometheus + Grafana + Spacelift exporter support
- GKE optimization
- Security hardening
- Cost optimization features
- Backup and DR capabilities

### Planned Features
- [ ] Multi-cluster federation
- [ ] Custom metrics from Spacelift webhooks
- [ ] Advanced cost analytics dashboard
- [ ] Automated scaling based on Spacelift load
- [ ] Integration with Google Cloud Monitoring

## License

This module is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

### Getting Help

1. **Documentation**: Check this README and the `/docs` folder
2. **Issues**: Create an issue in the repository
3. **Discussions**: Use GitHub Discussions for questions
4. **Enterprise Support**: Contact your Spacelift representative

### Requirements for Issues

When reporting issues, please include:

- Module version
- OpenTofu/Terraform version
- GKE cluster version
- Error messages and logs
- Minimal reproduction case

## Variables Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| google | ~> 5.0 |
| helm | ~> 2.12 |
| kubernetes | ~> 2.25 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 5.0 |
| helm | ~> 2.12 |
| kubernetes | ~> 2.25 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | GCP project ID where resources will be created | `string` | n/a | yes |
| gke_cluster_name | Name of the existing GKE cluster | `string` | n/a | yes |
| gke_cluster_location | Location of the existing GKE cluster | `string` | n/a | yes |
| spacelift_api_endpoint | Spacelift API endpoint | `string` | n/a | yes |
| spacelift_api_key_id | Spacelift API key ID | `string` | n/a | yes |
| spacelift_api_key_secret | Spacelift API key secret | `string` | n/a | yes |
| monitoring_namespace | Kubernetes namespace for monitoring components | `string` | `"spacelift-monitoring"` | no |
| enable_prometheus | Enable Prometheus deployment | `bool` | `true` | no |
| enable_spacelift_exporter | Enable Spacelift Prometheus exporter deployment | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| monitoring_namespace | Kubernetes namespace for monitoring components |
| prometheus_service_url | Internal service URL for Prometheus |
| grafana_service_url | Internal service URL for Grafana |
| spacelift_exporter_service_url | Internal service URL for Spacelift exporter |
| monitoring_endpoints | All monitoring service endpoints |
| monitoring_configuration | Summary of monitoring stack configuration |

<!-- END_TF_DOCS -->

---