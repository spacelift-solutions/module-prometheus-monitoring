# Project Configuration
variable "project_id" {
  description = "GCP project ID where resources will be created"
  type        = string
}

variable "gke_cluster_name" {
  description = "Name of the existing GKE cluster"
  type        = string
}

variable "gke_cluster_location" {
  description = "Location of the existing GKE cluster"
  type        = string
}

# Monitoring Configuration
variable "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring components"
  type        = string
  default     = "spacelift-monitoring"
}

variable "enable_prometheus" {
  description = "Enable Prometheus deployment"
  type        = bool
  default     = true
}

variable "enable_spacelift_exporter" {
  description = "Enable Spacelift Prometheus exporter deployment"
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Enable network policies for monitoring namespace"
  type        = bool
  default     = true
}

# Spacelift Configuration
variable "spacelift_api_endpoint" {
  description = "Spacelift API endpoint (e.g., https://myaccount.app.spacelift.io)"
  type        = string
  validation {
    condition     = can(regex("^https://[a-zA-Z0-9-]+\\.app\\.spacelift\\.io$", var.spacelift_api_endpoint))
    error_message = "Spacelift API endpoint must be in the format https://account.app.spacelift.io"
  }
}

variable "spacelift_api_key_id" {
  description = "Spacelift API key ID"
  type        = string
  sensitive   = true
}

variable "spacelift_api_key_secret" {
  description = "Spacelift API key secret"
  type        = string
  sensitive   = true
}

variable "create_spacelift_secret" {
  description = "Create Kubernetes secret for Spacelift API credentials"
  type        = bool
  default     = true
}

variable "existing_spacelift_secret_name" {
  description = "Name of existing Kubernetes secret containing Spacelift API credentials"
  type        = string
  default     = ""
}

variable "spacelift_scrape_timeout" {
  description = "Timeout for Spacelift API scraping"
  type        = string
  default     = "30s"
}

# Spacelift Exporter Configuration
variable "spacelift_exporter_version" {
  description = "Version of Spacelift Prometheus exporter"
  type        = string
  default     = "latest"
}

variable "spacelift_exporter_replicas" {
  description = "Number of Spacelift exporter replicas"
  type        = number
  default     = 1
  validation {
    condition     = var.spacelift_exporter_replicas >= 1 && var.spacelift_exporter_replicas <= 10
    error_message = "Spacelift exporter replicas must be between 1 and 10."
  }
}

variable "spacelift_exporter_resources" {
  description = "Resource requests and limits for Spacelift exporter"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
    }
  }
}

# Prometheus Configuration
variable "prometheus_chart_version" {
  description = "Version of kube-prometheus-stack Helm chart"
  type        = string
  default     = "56.0.0"
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus data"
  type        = string
  default     = "50Gi"
}

variable "prometheus_retention_days" {
  description = "Prometheus data retention period in days"
  type        = number
  default     = 30
  validation {
    condition     = var.prometheus_retention_days >= 1 && var.prometheus_retention_days <= 365
    error_message = "Prometheus retention days must be between 1 and 365."
  }
}

variable "prometheus_scrape_interval" {
  description = "Prometheus scrape interval"
  type        = string
  default     = "30s"
}

variable "prometheus_evaluation_interval" {
  description = "Prometheus evaluation interval"
  type        = string
  default     = "30s"
}

variable "prometheus_external_url" {
  description = "External URL for Prometheus (used for alerts and links)"
  type        = string
  default     = ""
}

# Grafana Configuration
variable "grafana_storage_size" {
  description = "Storage size for Grafana data"
  type        = string
  default     = "10Gi"
}

variable "grafana_external_url" {
  description = "External URL for Grafana"
  type        = string
  default     = ""
}

# Storage Configuration
variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "standard-rwo"
}

# Ingress Configuration
variable "enable_ingress" {
  description = "Enable ingress for Prometheus and Grafana"
  type        = bool
  default     = false
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "domain_name" {
  description = "Domain name for ingress"
  type        = string
  default     = ""
}

variable "enable_ssl" {
  description = "Enable SSL/TLS for ingress"
  type        = bool
  default     = true
}

variable "ssl_cert_issuer" {
  description = "SSL certificate issuer (cert-manager)"
  type        = string
  default     = "letsencrypt-prod"
}

# Workload Identity Configuration
variable "enable_workload_identity" {
  description = "Enable Workload Identity for GKE"
  type        = bool
  default     = false
}

variable "gcp_service_account_email" {
  description = "GCP service account email for Workload Identity"
  type        = string
  default     = ""
}

# Cost Optimization
variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "cost_optimization_config" {
  description = "Cost optimization configuration"
  type = object({
    enable_vertical_pod_autoscaling = bool
    enable_resource_quotas          = bool
    enable_limit_ranges            = bool
    enable_pod_disruption_budgets  = bool
  })
  default = {
    enable_vertical_pod_autoscaling = true
    enable_resource_quotas          = true
    enable_limit_ranges            = true
    enable_pod_disruption_budgets  = true
  }
}

# Monitoring and Alerting
variable "enable_alerts" {
  description = "Enable Prometheus alerting rules"
  type        = bool
  default     = true
}

variable "alert_manager_config" {
  description = "AlertManager configuration"
  type = object({
    slack_webhook_url = string
    email_recipients  = list(string)
    pagerduty_key    = string
  })
  default = {
    slack_webhook_url = ""
    email_recipients  = []
    pagerduty_key    = ""
  }
  sensitive = true
}

# Dashboard Configuration
variable "custom_dashboards" {
  description = "List of custom Grafana dashboard configurations"
  type = list(object({
    name        = string
    dashboard   = string
    folder      = string
    datasource  = string
  }))
  default = []
}

# Security Configuration
variable "enable_pod_security_policies" {
  description = "Enable pod security policies"
  type        = bool
  default     = true
}

variable "security_context_config" {
  description = "Security context configuration"
  type = object({
    run_as_non_root        = bool
    run_as_user           = number
    run_as_group          = number
    fs_group              = number
    read_only_root_filesystem = bool
  })
  default = {
    run_as_non_root        = true
    run_as_user           = 65534
    run_as_group          = 65534
    fs_group              = 65534
    read_only_root_filesystem = true
  }
}

# Multi-Environment Support
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Backup Configuration
variable "enable_backup" {
  description = "Enable backup for Prometheus and Grafana data"
  type        = bool
  default     = false
}

variable "backup_config" {
  description = "Backup configuration"
  type = object({
    schedule           = string
    retention_days     = number
    gcs_bucket_name   = string
    backup_encryption = bool
  })
  default = {
    schedule           = "0 2 * * *"
    retention_days     = 30
    gcs_bucket_name   = ""
    backup_encryption = true
  }
}