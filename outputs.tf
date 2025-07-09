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

output "grafana_admin_secret_name" {
  description = "Name of the Kubernetes secret containing Grafana admin credentials"
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

# ServiceMonitor Information
output "servicemonitor_created" {
  description = "Whether ServiceMonitor for Spacelift exporter was created"
  value       = var.enable_spacelift_exporter && var.enable_prometheus
}

output "servicemonitor_name" {
  description = "Name of the ServiceMonitor for Spacelift exporter"
  value       = var.enable_