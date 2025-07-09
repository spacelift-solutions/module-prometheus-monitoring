# Example Variables for Basic Spacelift Monitoring Deployment

# GCP Configuration
variable "project_id" {
  description = "GCP project ID where the monitoring stack will be deployed"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "gke_cluster_name" {
  description = "Name of the existing GKE cluster"
  type        = string
}

variable "gke_cluster_location" {
  description = "Location (region or zone) of the existing GKE cluster"
  type        = string
}

# Spacelift Configuration
variable "spacelift_api_endpoint" {
  description = "Spacelift API endpoint (e.g., https://your-account.app.spacelift.io)"
  type        = string
  validation {
    condition     = can(regex("^https://[a-zA-Z0-9-]+\\.app\\.spacelift\\.io$", var.spacelift_api_endpoint))
    error_message = "Spacelift API endpoint must be in the format https://account.app.spacelift.io"
  }
}

variable "spacelift_api_key_id" {
  description = "Spacelift API key ID (should be marked as sensitive in Spacelift)"
  type        = string
  sensitive   = true
}

variable "spacelift_api_key_secret" {
  description = "Spacelift API key secret (should be marked as sensitive in Spacelift)"
  type        = string
  sensitive   = true
}

# Optional Features
variable "enable_backup" {
  description = "Enable backup for monitoring data"
  type        = bool
  default     = false
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity for the monitoring service account"
  type        = bool
  default     = false
}

variable "monitoring_roles" {
  description = "List of IAM roles to grant to the monitoring service account"
  type        = list(string)
  default = [
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/storage.objectAdmin"
  ]
}

# Environment Configuration
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
  default = {
    ManagedBy = "terraform"
    Purpose   = "spacelift-monitoring"
  }
}