# Cost Optimization Resources for Spacelift Monitoring Stack

# Resource Quota for monitoring namespace
resource "kubernetes_resource_quota" "monitoring" {
  count = var.enable_cost_optimization && var.cost_optimization_config.enable_resource_quotas ? 1 : 0

  metadata {
    name      = "monitoring-quota"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "cost-optimization"
    }
  }

  spec {
    hard = {
      "requests.cpu"    = "10"
      "requests.memory" = "20Gi"
      "limits.cpu"      = "20"
      "limits.memory"   = "40Gi"
      "persistentvolumeclaims" = "10"
      "requests.storage" = "200Gi"
      "pods"            = "50"
      "services"        = "20"
      "configmaps"      = "50"
      "secrets"         = "50"
    }

    # ResourceQuota scopes (optional)
    scopes = ["NotTerminating"]
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Limit Range for monitoring namespace
resource "kubernetes_limit_range" "monitoring" {
  count = var.enable_cost_optimization && var.cost_optimization_config.enable_limit_ranges ? 1 : 0

  metadata {
    name      = "monitoring-limits"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "cost-optimization"
    }
  }

  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "1Gi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
      min = {
        cpu    = "50m"
        memory = "64Mi"
      }
      max = {
        cpu    = "2"
        memory = "4Gi"
      }
    }

    limit {
      type = "Pod"
      max = {
        cpu    = "4"
        memory = "8Gi"
      }
      min = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }

    limit {
      type = "PersistentVolumeClaim"
      min = {
        storage = "1Gi"
      }
      max = {
        storage = "100Gi"
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Pod Disruption Budget for Prometheus
resource "kubernetes_pod_disruption_budget" "prometheus" {
  count = var.enable_cost_optimization && var.cost_optimization_config.enable_pod_disruption_budgets && var.enable_prometheus ? 1 : 0

  metadata {
    name      = "prometheus-pdb"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "prometheus"
      "app.kubernetes.io/component" = "cost-optimization"
    }
  }

  spec {
    min_available = 1
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "prometheus"
        "prometheus"                  = "prometheus-kube-prometheus-prometheus"
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.prometheus
  ]
}

# Pod Disruption Budget for Spacelift Exporter
resource "kubernetes_pod_disruption_budget" "spacelift_exporter" {
  count = var.enable_cost_optimization && var.cost_optimization_config.enable_pod_disruption_budgets && var.enable_spacelift_exporter && var.spacelift_exporter_replicas > 1 ? 1 : 0

  metadata {
    name      = "spacelift-exporter-pdb"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "spacelift-exporter"
      "app.kubernetes.io/component" = "cost-optimization"
    }
  }

  spec {
    min_available = 1
    
    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "spacelift-exporter"
        "app.kubernetes.io/component" = "exporter"
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_deployment.spacelift_exporter
  ]
}

# Priority Classes for cost optimization
resource "kubernetes_priority_class" "monitoring_high" {
  count = var.enable_cost_optimization ? 1 : 0

  metadata {
    name = "monitoring-high-priority"
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "cost-optimization"
    }
  }

  value             = 1000
  global_default    = false
  description       = "High priority class for critical monitoring components"
  preemption_policy = "PreemptLowerPriority"
}

resource "kubernetes_priority_class" "monitoring_medium" {
  count = var.enable_cost_optimization ? 1 : 0

  metadata {
    name = "monitoring-medium-priority"
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "cost-optimization"
    }
  }

  value             = 500
  global_default    = false
  description       = "Medium priority class for standard monitoring components"
  preemption_policy = "PreemptLowerPriority"
}

resource "kubernetes_priority_class" "monitoring_low" {
  count = var.enable_cost_optimization ? 1 : 0

  metadata {
    name = "monitoring-low-priority"
    labels = {
      "app.kubernetes.io/name"      = "spacelift-monitoring"
      "app.kubernetes.io/component" = "cost-optimization"
    }
  }

  value             = 100
  global_default    = false
  description       = "Low priority class for non-critical monitoring components"
  preemption_policy = "Never"
}

# Vertical Pod Autoscaler for Spacelift Exporter (if VPA CRDs are available)
resource "kubernetes_manifest" "spacelift_exporter_vpa" {
  count = var.enable_cost_optimization && var.cost_optimization_config.enable_vertical_pod_autoscaling && var.enable_spacelift_exporter ? 1 : 0

  manifest = {
    apiVersion = "autoscaling.k8s.io/v1"
    kind       = "VerticalPodAutoscaler"
    metadata = {
      name      = "spacelift-exporter-vpa"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        "app.kubernetes.io/name"      = "spacelift-exporter"
        "app.kubernetes.io/component" = "cost-optimization"
      }
    }
    spec = {
      targetRef = {
        apiVersion = "apps/v1"
        kind       = "Deployment"
        name       = "spacelift-exporter"
      }
      updatePolicy = {
        updateMode = "Auto"
      }
      resourcePolicy = {
        containerPolicies = [{
          containerName = "spacelift-exporter"
          minAllowed = {
            cpu    = "50m"
            memory = "64Mi"
          }
          maxAllowed = {
            cpu    = "500m"
            memory = "512Mi"
          }
          controlledResources = ["cpu", "memory"]
        }]
      }
    }
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_deployment.spacelift_exporter
  ]
}