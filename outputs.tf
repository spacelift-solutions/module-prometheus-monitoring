# Namespace Information
output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring components"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "monitoring_namespace_uid" {
  description = "UID of the monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].uid
}

# Service Account Information
output "service_account_name" {
  description = "Name of the monitoring service account"
  value       = kubernetes_service_account.monitoring.metadata[0].name
}

output "service_account_uid" {
  description = "UID of the monitoring service account"
  value       = kubernetes_service_account.monitoring.metadata[0].uid
}

# Prometheus Information
output "prometheus_enabled" {
  description = "Whether Prometheus is enabled and deployed"
  value       = var.enable_prometheus
}

output "prometheus_release_name" {
  description = "Helm release name for Prometheus"
  value       = var.enable_prometheus ? helm_release.prometheus[0].name : null
}

output "prometheus_chart_version" {
  description = "Version of the Prometheus Helm chart deployed"
  value       = var.enable_prometheus ? helm_release.prometheus[0].version : null
}

output "prometheus_service_url" {
  description = "Internal service URL for Prometheus"
  value       = var.enable_prometheus ? "http://prometheus-kube-prometheus-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090" : null
}

output "prometheus_external_url" {
  description = "External URL for Prometheus (if ingress is enabled)"
  value       = var.enable_ingress && var.prometheus_external_url != "" ? var.prometheus_external_url : null
}

# Grafana Information
output "grafana_service_url" {
  description = "Internal service URL for Grafana"
  value       = var.enable_prometheus ? "http://prometheus-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local" : null
}

output "grafana_external_url" {
  description = "External URL for Grafana (if ingress is enabled)"
  value       = var.enable_ingress && var.grafana_external_url != "" ? var.grafana_external_url : null
}

output "grafana_default_admin_secret" {
  description = "Name of the default Kubernetes secret containing Grafana admin credentials (from Helm chart)"
  value       = var.enable_prometheus ? "prometheus-grafana" : null
}

# Spacelift Exporter Information
output "spacelift_exporter_enabled" {
  description = "Whether Spacelift exporter is enabled and deployed"
  value       = var.enable_spacelift_exporter
}

output "spacelift_exporter_deployment_name" {
  description = "Name of the Spacelift exporter deployment"
  value       = var.enable_spacelift_exporter ? kubernetes_deployment.spacelift_exporter[0].metadata[0].name : null
}

output "spacelift_exporter_service_name" {
  description = "Name of the Spacelift exporter service"
  value       = var.enable_spacelift_exporter ? kubernetes_service.spacelift_exporter[0].metadata[0].name : null
}

output "spacelift_exporter_service_url" {
  description = "Internal service URL for Spacelift exporter"
  value       = var.enable_spacelift_exporter ? "http://spacelift-exporter.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9953" : null
}

output "spacelift_exporter_metrics_url" {
  description = "Metrics endpoint URL for Spacelift exporter"
  value       = var.enable_spacelift_exporter ? "http://spacelift-exporter.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9953/metrics" : null
}

output "spacelift_exporter_version" {
  description = "Version of the Spacelift exporter deployed"
  value       = var.enable_spacelift_exporter ? var.spacelift_exporter_version : null
}

# Secret Information
output "spacelift_secret_created" {
  description = "Whether Spacelift API secret was created by this module"
  value       = var.create_spacelift_secret
}

output "spacelift_secret_name" {
  description = "Name of the Kubernetes secret containing Spacelift API credentials"
  value       = var.create_spacelift_secret ? kubernetes_secret.spacelift_api[0].metadata[0].name : var.existing_spacelift_secret_name
}

# Scraping Configuration Information
output "prometheus_scraping_configured" {
  description = "Whether Prometheus is configured to scrape Spacelift exporter"
  value       = var.enable_spacelift_exporter && var.enable_prometheus
}

# ServiceMonitor Information
output "service_monitor_created" {
  description = "Whether ServiceMonitor for Spacelift exporter was created"
  value       = var.enable_spacelift_exporter && var.enable_prometheus
}

output "service_monitor_name" {
  description = "Name of the ServiceMonitor for Spacelift exporter"
  value       = var.enable_spacelift_exporter && var.enable_prometheus ? "spacelift-exporter" : null
}

# Network Policy Information
output "network_policy_enabled" {
  description = "Whether network policies are enabled for the monitoring namespace"
  value       = var.enable_network_policy
}

output "network_policy_name" {
  description = "Name of the network policy for monitoring namespace"
  value       = var.enable_network_policy ? kubernetes_network_policy.monitoring[0].metadata[0].name : null
}

# Grafana Admin Credentials Information
output "grafana_admin_secret_name" {
  description = "Name of the custom Kubernetes secret containing Grafana admin credentials"
  value       = var.enable_prometheus ? kubernetes_secret.grafana_admin[0].metadata[0].name : null
}

output "grafana_admin_username" {
  description = "Grafana admin username"
  value       = "admin"
}

# Combined Monitoring Endpoints
output "monitoring_endpoints" {
  description = "All monitoring service endpoints"
  value = {
    prometheus = {
      internal = var.enable_prometheus ? "http://prometheus-kube-prometheus-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090" : null
      external = var.enable_ingress && var.prometheus_external_url != "" ? var.prometheus_external_url : null
    }
    grafana = {
      internal = var.enable_prometheus ? "http://prometheus-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local" : null
      external = var.enable_ingress && var.grafana_external_url != "" ? var.grafana_external_url : null
    }
    spacelift_exporter = {
      internal = var.enable_spacelift_exporter ? "http://spacelift-exporter.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9953" : null
      metrics  = var.enable_spacelift_exporter ? "http://spacelift-exporter.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9953/metrics" : null
    }
    alertmanager = {
      internal = var.enable_prometheus ? "http://prometheus-kube-prometheus-alertmanager.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093" : null
    }
  }
}

# Configuration Summary
output "monitoring_configuration" {
  description = "Summary of monitoring stack configuration"
  value = {
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    components = {
      prometheus_enabled         = var.enable_prometheus
      spacelift_exporter_enabled = var.enable_spacelift_exporter
      network_policy_enabled     = var.enable_network_policy
      ingress_enabled           = var.enable_ingress
      ssl_enabled               = var.enable_ssl
      workload_identity_enabled = var.enable_workload_identity
      cost_optimization_enabled = var.enable_cost_optimization
      backup_enabled            = var.enable_backup
      alerts_enabled            = var.enable_alerts
    }
    versions = {
      prometheus_chart  = var.enable_prometheus ? helm_release.prometheus[0].version : null
      spacelift_exporter = var.enable_spacelift_exporter ? var.spacelift_exporter_version : null
    }
    storage = {
      storage_class           = var.storage_class
      prometheus_storage_size = var.prometheus_storage_size
      grafana_storage_size    = var.grafana_storage_size
      retention_days          = var.prometheus_retention_days
    }
    environment = var.environment
    tags        = var.tags
  }
}

# Instructions for accessing services
output "access_instructions" {
  description = "Instructions for accessing the monitoring services"
  value = <<-EOT
    To access the monitoring services:
    
    1. Port-forward to Prometheus:
       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/prometheus-kube-prometheus-prometheus 9090:9090
       Then visit: http://localhost:9090
    
    2. Port-forward to Grafana:
       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/prometheus-grafana 3000:80
       Then visit: http://localhost:3000
       
    3. Get Grafana admin password:
       kubectl get secret -n ${kubernetes_namespace.monitoring.metadata[0].name} grafana-admin-credentials -o jsonpath="{.data.admin-password}" | base64 -d
    
    4. Port-forward to AlertManager:
       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/prometheus-kube-prometheus-alertmanager 9093:9093
       Then visit: http://localhost:9093
    
    5. Check Spacelift exporter metrics:
       kubectl port-forward -n ${kubernetes_namespace.monitoring.metadata[0].name} svc/spacelift-exporter 9953:9953
       Then visit: http://localhost:9953/metrics
  EOT
}
