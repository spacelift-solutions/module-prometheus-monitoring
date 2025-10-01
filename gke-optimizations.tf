# GKE-Specific Optimizations for Monitoring Stack

# Workload Identity Binding for monitoring service account
resource "google_service_account_iam_binding" "monitoring_workload_identity" {
  count = var.enable_workload_identity && var.gcp_service_account_email != "" ? 1 : 0

  service_account_id = var.gcp_service_account_email
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.monitoring.metadata[0].name}/${kubernetes_service_account.monitoring.metadata[0].name}]"
  ]
}

# GKE-specific annotations for Spacelift exporter deployment
resource "kubernetes_annotations" "spacelift_exporter_gke" {
  count = var.enable_spacelift_exporter && var.enable_gke_optimizations ? 1 : 0

  api_version = "apps/v1"
  kind        = "Deployment"
  
  metadata {
    name      = kubernetes_deployment.spacelift_exporter[0].metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  annotations = {
    # GKE Autopilot compatible annotations
    "autopilot.gke.io/resource-adjustment" = jsonencode({
      "spacelift-exporter" = {
        "requests" = {
          "cpu"    = "100m"
          "memory" = "128Mi"
        }
      }
    })
    
    # Node selector for specific node pools
    "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"
  }

  depends_on = [kubernetes_deployment.spacelift_exporter]
}

# GKE Monitoring ConfigMap for Prometheus to scrape GKE metrics
resource "kubernetes_config_map" "gke_metrics_config" {
  count = var.enable_prometheus && var.enable_gke_metrics_collection ? 1 : 0

  metadata {
    name      = "gke-metrics-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "gke-metrics"
      "app.kubernetes.io/component" = "configuration"
    }
  }

  data = {
    "gke-metrics.yaml" = yamlencode({
      scrape_configs = [
        {
          job_name = "gke-kubelet"
          scheme   = "https"
          tls_config = {
            ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          }
          bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          kubernetes_sd_configs = [{
            role = "node"
          }]
          relabel_configs = [
            {
              action = "labelmap"
              regex  = "__meta_kubernetes_node_label_(.+)"
            }
          ]
        },
        {
          job_name = "gke-cadvisor"
          scheme   = "https"
          tls_config = {
            ca_file = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
          }
          bearer_token_file = "/var/run/secrets/kubernetes.io/serviceaccount/token"
          kubernetes_sd_configs = [{
            role = "node"
          }]
          relabel_configs = [
            {
              target_label = "__address__"
              replacement  = "kubernetes.default.svc:443"
            },
            {
              source_labels = ["__meta_kubernetes_node_name"]
              regex         = "(.+)"
              target_label  = "__metrics_path__"
              replacement   = "/api/v1/nodes/$${1}/proxy/metrics/cadvisor"
            }
          ]
        }
      ]
    })
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# GKE Backup Configuration using Cloud Storage
resource "google_storage_bucket" "monitoring_backup" {
  count    = var.enable_backup && var.backup_config.gcs_bucket_name == "" ? 1 : 0
  
  name     = "${var.project_id}-monitoring-backup-${var.environment}"
  location = var.gke_cluster_location
  
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = var.backup_config.retention_days
    }
  }
  
  lifecycle_rule {
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 30
    }
  }
  
  lifecycle_rule {
    action {
      type = "SetStorageClass"
      storage_class = "ARCHIVE"
    }
    condition {
      age = 90
    }
  }
  
  versioning {
    enabled = true
  }
  
  encryption {
    default_kms_key_name = var.backup_config.backup_encryption && var.gcp_kms_key_id != "" ? var.gcp_kms_key_id : null
  }
  
  uniform_bucket_level_access = true
  
  labels = merge(
    var.tags,
    {
      environment = var.environment
      purpose     = "monitoring-backup"
      managed_by  = "terraform"
    }
  )
}

# IAM binding for backup service account to access GCS
resource "google_storage_bucket_iam_member" "backup_writer" {
  count = var.enable_backup && var.enable_workload_identity && var.gcp_service_account_email != "" ? 1 : 0
  
  bucket = var.backup_config.gcs_bucket_name != "" ? var.backup_config.gcs_bucket_name : google_storage_bucket.monitoring_backup[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.gcp_service_account_email}"
}

# GKE-specific node affinity for monitoring workloads
locals {
  gke_node_affinity = var.enable_gke_node_affinity ? {
    nodeAffinity = {
      preferredDuringSchedulingIgnoredDuringExecution = [
        {
          weight = 100
          preference = {
            matchExpressions = [
              {
                key      = "cloud.google.com/gke-nodepool"
                operator = "In"
                values   = var.preferred_node_pools
              }
            ]
          }
        }
      ]
    }
  } : {}
  
  gke_tolerations = var.enable_gke_spot_nodes ? [
    {
      key      = "cloud.google.com/gke-preemptible"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    },
    {
      key      = "cloud.google.com/gke-spot"
      operator = "Equal"
      value    = "true"
      effect   = "NoSchedule"
    }
  ] : []
}

# Update Helm values with GKE-specific configurations
resource "local_file" "gke_prometheus_values" {
  count = var.enable_prometheus && var.enable_gke_optimizations ? 1 : 0

  filename = "${path.module}/helm-values/prometheus-gke.yaml"
  content = templatefile("${path.module}/helm-values/prometheus.yaml", merge(
    {
      namespace                = kubernetes_namespace.monitoring.metadata[0].name
      service_account         = kubernetes_service_account.monitoring.metadata[0].name
      storage_class          = var.storage_class
      prometheus_storage_size = var.prometheus_storage_size
      grafana_storage_size   = var.grafana_storage_size
      retention_days         = var.prometheus_retention_days
      external_url          = var.prometheus_external_url
      grafana_external_url  = var.grafana_external_url
      enable_ingress        = var.enable_ingress
      ingress_class         = var.ingress_class
      domain_name           = var.domain_name
      enable_ssl            = var.enable_ssl
      ssl_cert_issuer       = var.ssl_cert_issuer
      scrape_interval       = var.prometheus_scrape_interval
      evaluation_interval   = var.prometheus_evaluation_interval
    },
    {
      gke_affinity    = yamlencode(local.gke_node_affinity)
      gke_tolerations = yamlencode(local.gke_tolerations)
    }
  ))
}

# GKE Workload Identity annotation for backup service account
resource "kubernetes_annotations" "backup_workload_identity" {
  count = var.enable_backup && var.enable_workload_identity && var.gcp_service_account_email != "" ? 1 : 0

  api_version = "v1"
  kind        = "ServiceAccount"
  
  metadata {
    name      = kubernetes_service_account.backup[0].metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  annotations = {
    "iam.gke.io/gcp-service-account" = var.gcp_service_account_email
  }

  depends_on = [kubernetes_service_account.backup]
}

# Cloud Monitoring integration for GKE metrics
resource "google_monitoring_dashboard" "spacelift_gke" {
  count = var.enable_gke_cloud_monitoring ? 1 : 0

  dashboard_json = jsonencode({
    displayName = "Spacelift GKE Monitoring"
    gridLayout = {
      widgets = [
        {
          title = "Spacelift Pending Runs"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                prometheusQuery = {
                  projectName = var.project_id
                  query       = "spacelift_public_worker_pool_runs_pending"
                }
              }
            }]
          }
        },
        {
          title = "GKE Cluster CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_cluster\" AND metric.type=\"kubernetes.io/node/cpu/allocatable_utilization\""
                }
              }
            }]
          }
        },
        {
          title = "GKE Cluster Memory Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"k8s_cluster\" AND metric.type=\"kubernetes.io/node/memory/allocatable_utilization\""
                }
              }
            }]
          }
        }
      ]
    }
  })
}