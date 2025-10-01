# Spacelift Prometheus Monitoring Stack
# This module deploys a comprehensive monitoring solution for Spacelift on GKE
# including Prometheus, Grafana, and the Spacelift Prometheus exporter

# Local values for consistent naming
locals {
  name_prefix = "spacelift-monitoring"
  common_labels = merge(
    var.tags,
    {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "spacelift-monitoring"
      "environment"                   = var.environment
    }
  )
  
  prometheus_name     = "${local.name_prefix}-prometheus"
  grafana_name        = "${local.name_prefix}-grafana"
  exporter_name       = "${local.name_prefix}-exporter"
  alertmanager_name   = "${local.name_prefix}-alertmanager"
  backup_name         = "${local.name_prefix}-backup"
}

# Data sources for existing GKE cluster
data "google_client_config" "default" {}

data "google_container_cluster" "primary" {
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = var.project_id
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = merge(
      local.common_labels,
      {
        name                           = var.monitoring_namespace
        "app.kubernetes.io/name"       = local.name_prefix
        "app.kubernetes.io/component"  = "namespace"
      }
    )
  }
}

# Service account for monitoring components
resource "kubernetes_service_account" "monitoring" {
  metadata {
    name      = "spacelift-monitoring"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "service-account"
    }
    annotations = var.enable_workload_identity ? {
      "iam.gke.io/gcp-service-account" = var.gcp_service_account_email
    } : {}
  }
}

# ClusterRole for monitoring components
resource "kubernetes_cluster_role" "monitoring" {
  metadata {
    name = "spacelift-monitoring"
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "rbac"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

# ClusterRoleBinding for monitoring components
resource "kubernetes_cluster_role_binding" "monitoring" {
  metadata {
    name = "spacelift-monitoring"
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "rbac"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.monitoring.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.monitoring.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# Random password for Grafana admin user
resource "random_password" "grafana_admin" {
  count   = var.enable_prometheus ? 1 : 0
  length  = 24
  special = true
}

# Kubernetes secret for Grafana admin credentials
resource "kubernetes_secret" "grafana_admin" {
  count = var.enable_prometheus ? 1 : 0

  metadata {
    name      = "grafana-admin-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "grafana"
      "app.kubernetes.io/component" = "secrets"
    }
  }

  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin[0].result
  }

  type = "Opaque"
}

# Kubernetes secret for Spacelift API credentials
resource "kubernetes_secret" "spacelift_api" {
  count = var.create_spacelift_secret ? 1 : 0

  metadata {
    name      = "spacelift-api-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "secrets"
    }
  }

  data = {
    api-endpoint   = var.spacelift_api_endpoint
    api-key-id     = var.spacelift_api_key_id
    api-key-secret = var.spacelift_api_key_secret
  }

  type = "Opaque"
}

# Prometheus deployment using Helm
resource "helm_release" "prometheus" {
  count = var.enable_prometheus ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [templatefile("${path.module}/helm-values/prometheus.yaml", {
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
  })]

  timeout = 2400
  wait    = true
  wait_for_jobs = true

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_service_account.monitoring,
    kubernetes_cluster_role_binding.monitoring,
    kubernetes_secret.grafana_admin
  ]
}

# Spacelift Prometheus Exporter deployment
resource "kubernetes_deployment" "spacelift_exporter" {
  count = var.enable_spacelift_exporter ? 1 : 0

  metadata {
    name      = "spacelift-exporter"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "spacelift-exporter"
      "app.kubernetes.io/component" = "exporter"
      "app.kubernetes.io/version"   = var.spacelift_exporter_version
    }
  }

  spec {
    replicas = var.spacelift_exporter_replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "spacelift-exporter"
        "app.kubernetes.io/component" = "exporter"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "spacelift-exporter"
          "app.kubernetes.io/component" = "exporter"
          "app.kubernetes.io/version"   = var.spacelift_exporter_version
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9953"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.monitoring.metadata[0].name

        container {
          name  = "spacelift-exporter"
          image = "public.ecr.aws/spacelift/promex:${var.spacelift_exporter_version}"

          port {
            name           = "metrics"
            container_port = 9953
            protocol       = "TCP"
          }

          env {
            name = "SPACELIFT_PROMEX_API_ENDPOINT"
            value_from {
              secret_key_ref {
                name = var.create_spacelift_secret ? kubernetes_secret.spacelift_api[0].metadata[0].name : var.existing_spacelift_secret_name
                key  = "api-endpoint"
              }
            }
          }

          env {
            name = "SPACELIFT_PROMEX_API_KEY_ID"
            value_from {
              secret_key_ref {
                name = var.create_spacelift_secret ? kubernetes_secret.spacelift_api[0].metadata[0].name : var.existing_spacelift_secret_name
                key  = "api-key-id"
              }
            }
          }

          env {
            name = "SPACELIFT_PROMEX_API_KEY_SECRET"
            value_from {
              secret_key_ref {
                name = var.create_spacelift_secret ? kubernetes_secret.spacelift_api[0].metadata[0].name : var.existing_spacelift_secret_name
                key  = "api-key-secret"
              }
            }
          }

          env {
            name  = "SPACELIFT_PROMEX_LISTEN_ADDRESS"
            value = ":9953"
          }

          env {
            name  = "SPACELIFT_PROMEX_SCRAPE_TIMEOUT"
            value = var.spacelift_scrape_timeout
          }

          resources {
            requests = {
              cpu    = var.spacelift_exporter_resources.requests.cpu
              memory = var.spacelift_exporter_resources.requests.memory
            }
            limits = {
              cpu    = var.spacelift_exporter_resources.limits.cpu
              memory = var.spacelift_exporter_resources.limits.memory
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "metrics"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "metrics"
            }
            initial_delay_seconds = 30
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root           = true
            run_as_user               = 65534
            capabilities {
              drop = ["ALL"]
            }
          }
        }

        security_context {
          fs_group    = 65534
          run_as_user = 65534
        }

        restart_policy = "Always"
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_service_account.monitoring
  ]
}

# Service for Spacelift Exporter
resource "kubernetes_service" "spacelift_exporter" {
  count = var.enable_spacelift_exporter ? 1 : 0

  metadata {
    name      = "spacelift-exporter"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "spacelift-exporter"
      "app.kubernetes.io/component" = "exporter"
    }
    annotations = {
      "prometheus.io/scrape" = "true"
      "prometheus.io/port"   = "9953"
      "prometheus.io/path"   = "/metrics"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "spacelift-exporter"
      "app.kubernetes.io/component" = "exporter"
    }

    port {
      name        = "metrics"
      port        = 9953
      target_port = "metrics"
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.spacelift_exporter]
}

# ConfigMap for Spacelift Grafana Dashboard
resource "kubernetes_config_map" "spacelift_dashboard" {
  count = var.enable_prometheus && var.enable_spacelift_exporter ? 1 : 0

  metadata {
    name      = "spacelift-dashboard"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "grafana_dashboard" = "1"
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "dashboard"
    }
  }

  data = {
    "spacelift-dashboard.json" = file("${path.module}/dashboards/spacelift-dashboard.json")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ServiceMonitor for Spacelift Exporter to enable Prometheus scraping
resource "kubernetes_manifest" "spacelift_service_monitor" {
  count = var.enable_spacelift_exporter && var.enable_prometheus ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "spacelift-exporter"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        "app.kubernetes.io/name"      = "spacelift-exporter"
        "app.kubernetes.io/component" = "exporter"
        "prometheus"                  = "kube-prometheus"
        "release"                     = "prometheus"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"      = "spacelift-exporter"
          "app.kubernetes.io/component" = "exporter"
        }
      }
      endpoints = [{
        port     = "metrics"
        interval = var.prometheus_scrape_interval
        path     = "/metrics"
        scrapeTimeout = "30s"
      }]
    }
  }

  depends_on = [
    kubernetes_service.spacelift_exporter,
    helm_release.prometheus
  ]
}

# Network Policy for monitoring namespace (if enabled)
resource "kubernetes_network_policy" "monitoring" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "spacelift-monitoring"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = kubernetes_namespace.monitoring.metadata[0].name
          }
        }
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
    }

    egress {
      # Allow all egress traffic (pods can communicate outbound)
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}