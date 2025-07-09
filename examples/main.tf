# Basic Spacelift Monitoring Stack Example
# This example demonstrates the minimal configuration needed to deploy
# the Spacelift monitoring stack on an existing GKE cluster

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Configure the Kubernetes Provider
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

# Configure the Helm Provider
provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

# Data sources
data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = var.project_id
}

# Deploy Spacelift monitoring stack
module "spacelift_monitoring" {
  source = "../../"
  
  # Required GCP Configuration
  project_id           = var.project_id
  gke_cluster_name     = var.gke_cluster_name
  gke_cluster_location = var.gke_cluster_location
  
  # Required Spacelift Configuration
  spacelift_api_endpoint   = var.spacelift_api_endpoint
  spacelift_api_key_id     = var.spacelift_api_key_id
  spacelift_api_key_secret = var.spacelift_api_key_secret
  
  # Basic Configuration
  monitoring_namespace = "spacelift-monitoring"
  environment         = "dev"
  
  # Component Enablement
  enable_prometheus         = true
  enable_spacelift_exporter = true
  enable_network_policy     = true
  
  # Storage Configuration
  storage_class            = "standard-rwo"
  prometheus_storage_size  = "50Gi"
  grafana_storage_size     = "10Gi"
  prometheus_retention_days = 30
  
  # Cost Optimization
  enable_cost_optimization = true
  
  # Tags
  tags = {
    Environment   = "development"
    Team          = "platform"
    Purpose       = "spacelift-monitoring"
    ManagedBy     = "terraform"
    CostCenter    = "engineering"
  }
}

# Optional: Create a GCS bucket for backups
resource "google_storage_bucket" "monitoring_backup" {
  count    = var.enable_backup ? 1 : 0
  name     = "${var.project_id}-spacelift-monitoring-backup"
  location = var.region
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
  
  uniform_bucket_level_access = true
  
  labels = {
    environment = "dev"
    purpose     = "monitoring-backup"
  }
}

# Optional: Create a service account for Workload Identity
resource "google_service_account" "monitoring" {
  count        = var.enable_workload_identity ? 1 : 0
  account_id   = "spacelift-monitoring"
  display_name = "Spacelift Monitoring Service Account"
  description  = "Service account for Spacelift monitoring stack"
}

# Optional: Grant necessary permissions to the service account
resource "google_project_iam_member" "monitoring_roles" {
  count   = var.enable_workload_identity ? length(var.monitoring_roles) : 0
  project = var.project_id
  role    = var.monitoring_roles[count.index]
  member  = "serviceAccount:${google_service_account.monitoring[0].email}"
}

# Optional: Bind the service account to the Kubernetes service account
resource "google_service_account_iam_binding" "monitoring_workload_identity" {
  count              = var.enable_workload_identity ? 1 : 0
  service_account_id = google_service_account.monitoring[0].name
  role               = "roles/iam.workloadIdentityUser"
  
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${module.spacelift_monitoring.monitoring_namespace}/spacelift-monitoring]"
  ]
}