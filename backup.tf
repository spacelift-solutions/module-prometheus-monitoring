# Backup Configuration for Prometheus and Grafana Data

# Service Account for backup jobs
resource "kubernetes_service_account" "backup" {
  count = var.enable_backup ? 1 : 0

  metadata {
    name      = "monitoring-backup"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "monitoring-backup"
      "app.kubernetes.io/component" = "backup"
    }
    annotations = var.enable_workload_identity && var.gcp_service_account_email != "" ? {
      "iam.gke.io/gcp-service-account" = var.gcp_service_account_email
    } : {}
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Role for backup operations
resource "kubernetes_role" "backup" {
  count = var.enable_backup ? 1 : 0

  metadata {
    name      = "monitoring-backup"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "monitoring-backup"
      "app.kubernetes.io/component" = "backup"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/exec"]
    verbs      = ["get", "list", "create"]
  }

  rule {
    api_groups = [""]
    resources  = ["persistentvolumeclaims"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list"]
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# RoleBinding for backup service account
resource "kubernetes_role_binding" "backup" {
  count = var.enable_backup ? 1 : 0

  metadata {
    name      = "monitoring-backup"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "monitoring-backup"
      "app.kubernetes.io/component" = "backup"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.backup[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.backup[0].metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  depends_on = [
    kubernetes_service_account.backup,
    kubernetes_role.backup
  ]
}

# ConfigMap for backup script
resource "kubernetes_config_map" "backup_script" {
  count = var.enable_backup ? 1 : 0

  metadata {
    name      = "backup-script"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "monitoring-backup"
      "app.kubernetes.io/component" = "backup"
    }
  }

  data = {
    "backup.sh" = <<-EOF
      #!/bin/bash
      set -e
      
      echo "Starting backup process..."
      DATE=$(date +%Y%m%d-%H%M%S)
      BACKUP_DIR="/backup"
      
      # Function to backup Prometheus data
      backup_prometheus() {
        echo "Backing up Prometheus data..."
        PROMETHEUS_POD=$(kubectl get pods -n ${var.monitoring_namespace} -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
        
        if [ -z "$PROMETHEUS_POD" ]; then
          echo "Warning: No Prometheus pod found"
          return 1
        fi
        
        # Create snapshot via Prometheus API
        kubectl exec -n ${var.monitoring_namespace} $PROMETHEUS_POD -c prometheus -- \
          curl -XPOST http://localhost:9090/api/v1/admin/tsdb/snapshot
        
        # Copy snapshot to backup location
        kubectl cp ${var.monitoring_namespace}/$PROMETHEUS_POD:/prometheus/snapshots \
          $BACKUP_DIR/prometheus-$DATE -c prometheus
        
        echo "Prometheus backup completed"
      }
      
      # Function to backup Grafana dashboards and datasources
      backup_grafana() {
        echo "Backing up Grafana configuration..."
        
        # Backup ConfigMaps (dashboards)
        kubectl get configmaps -n ${var.monitoring_namespace} \
          -l grafana_dashboard=1 -o yaml > $BACKUP_DIR/grafana-dashboards-$DATE.yaml
        
        # Backup Grafana database (if using sqlite)
        GRAFANA_POD=$(kubectl get pods -n ${var.monitoring_namespace} -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
        
        if [ ! -z "$GRAFANA_POD" ]; then
          kubectl cp ${var.monitoring_namespace}/$GRAFANA_POD:/var/lib/grafana/grafana.db \
            $BACKUP_DIR/grafana-db-$DATE.db 2>/dev/null || true
        fi
        
        echo "Grafana backup completed"
      }
      
      # Function to upload to GCS
      upload_to_gcs() {
        if [ ! -z "${var.backup_config.gcs_bucket_name}" ]; then
          echo "Uploading backups to GCS..."
          gsutil -m cp -r $BACKUP_DIR/* gs://${var.backup_config.gcs_bucket_name}/monitoring-backup/$DATE/
          echo "Upload to GCS completed"
        fi
      }
      
      # Function to cleanup old backups
      cleanup_old_backups() {
        echo "Cleaning up old backups..."
        find $BACKUP_DIR -type f -mtime +${var.backup_config.retention_days} -delete
        
        if [ ! -z "${var.backup_config.gcs_bucket_name}" ]; then
          # Clean up old backups in GCS
          gsutil -m rm -r gs://${var.backup_config.gcs_bucket_name}/monitoring-backup/\
            $(date -d "${var.backup_config.retention_days} days ago" +%Y%m%d)* 2>/dev/null || true
        fi
        
        echo "Cleanup completed"
      }
      
      # Main execution
      mkdir -p $BACKUP_DIR
      
      backup_prometheus
      backup_grafana
      upload_to_gcs
      cleanup_old_backups
      
      echo "Backup process completed successfully"
    EOF
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# CronJob for scheduled backups
resource "kubernetes_cron_job" "backup" {
  count = var.enable_backup ? 1 : 0

  metadata {
    name      = "monitoring-backup"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "monitoring-backup"
      "app.kubernetes.io/component" = "backup"
    }
  }

  spec {
    schedule                      = var.backup_config.schedule
    concurrency_policy           = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit    = 1
    
    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "monitoring-backup"
          "app.kubernetes.io/component" = "backup"
        }
      }
      
      spec {
        template {
          metadata {
            labels = {
              "app.kubernetes.io/name"      = "monitoring-backup"
              "app.kubernetes.io/component" = "backup"
            }
          }
          
          spec {
            service_account_name = kubernetes_service_account.backup[0].metadata[0].name
            restart_policy       = "OnFailure"
            
            init_container {
              name  = "install-tools"
              image = "google/cloud-sdk:alpine"
              
              command = [
                "sh", "-c",
                "apk add --no-cache curl kubectl && gcloud auth activate-service-account --key-file=/var/run/secrets/cloud.google.com/service-account.json || true"
              ]
              
              volume_mount {
                name       = "gcp-service-account"
                mount_path = "/var/run/secrets/cloud.google.com"
                read_only  = true
              }
            }
            
            container {
              name  = "backup"
              image = "google/cloud-sdk:alpine"
              
              command = ["/bin/bash", "/scripts/backup.sh"]
              
              env {
                name  = "GOOGLE_APPLICATION_CREDENTIALS"
                value = "/var/run/secrets/cloud.google.com/service-account.json"
              }
              
              volume_mount {
                name       = "backup-script"
                mount_path = "/scripts"
                read_only  = true
              }
              
              volume_mount {
                name       = "backup-data"
                mount_path = "/backup"
              }
              
              volume_mount {
                name       = "gcp-service-account"
                mount_path = "/var/run/secrets/cloud.google.com"
                read_only  = true
              }
              
              resources {
                requests = {
                  cpu    = "100m"
                  memory = "256Mi"
                }
                limits = {
                  cpu    = "500m"
                  memory = "1Gi"
                }
              }
            }
            
            volume {
              name = "backup-script"
              config_map {
                name         = kubernetes_config_map.backup_script[0].metadata[0].name
                default_mode = "0755"
              }
            }
            
            volume {
              name = "backup-data"
              empty_dir {}
            }
            
            volume {
              name = "gcp-service-account"
              secret {
                secret_name  = var.gcp_service_account_secret_name != "" ? var.gcp_service_account_secret_name : "gcp-service-account"
                default_mode = "0400"
                optional     = true
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_service_account.backup,
    kubernetes_role_binding.backup,
    kubernetes_config_map.backup_script
  ]
}

# PersistentVolumeClaim for backup storage (optional local backup)
resource "kubernetes_persistent_volume_claim" "backup" {
  count = var.enable_backup && var.backup_config.enable_local_backup ? 1 : 0

  metadata {
    name      = "monitoring-backup-pvc"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "monitoring-backup"
      "app.kubernetes.io/component" = "backup"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    
    resources {
      requests = {
        storage = var.backup_config.backup_storage_size
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}