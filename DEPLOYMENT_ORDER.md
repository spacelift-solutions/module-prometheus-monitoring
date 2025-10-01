# Deployment Order Guide

This monitoring module requires an existing GKE cluster. Here's the correct deployment order:

## Prerequisites

1. **GCP Project Setup**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **GKE Cluster** - You need an existing GKE cluster first!

## Option 1: Create GKE Cluster First

If you don't have a cluster yet, create one:

```bash
# Create a GKE cluster
gcloud container clusters create demo-env-gke-cluster \
  --location=europe-west4 \
  --machine-type=e2-standard-4 \
  --num-nodes=3 \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=10 \
  --enable-autorepair \
  --enable-autoupgrade

# Get credentials
gcloud container clusters get-credentials demo-env-gke-cluster \
  --location=europe-west4
```

## Option 2: Two-Stage Terraform Deployment

If you want to create both the cluster AND monitoring in the same Terraform configuration:

### Stage 1: Create cluster-only resources

```hcl
# main.tf - Stage 1
module "gke_cluster" {
  source = "./modules/gke-cluster"
  
  project_id = var.project_id
  region     = var.region
  # ... cluster configuration
}
```

Apply stage 1:
```bash
terraform apply -target=module.gke_cluster
```

### Stage 2: Deploy monitoring

```hcl
# main.tf - Stage 2  
module "spacelift_monitoring" {
  source = "./modules/spacelift-monitoring"
  
  project_id           = var.project_id
  gke_cluster_name     = module.gke_cluster.cluster_name
  gke_cluster_location = module.gke_cluster.cluster_location
  # ... monitoring configuration
  
  depends_on = [module.gke_cluster]
}
```

Apply stage 2:
```bash
terraform apply
```

## Option 3: Use Existing Cluster

If you have an existing cluster, just set the correct variables:

```hcl
# terraform.tfvars
project_id           = "your-project-id"
gke_cluster_name     = "your-existing-cluster"
gke_cluster_location = "europe-west4"  # Must match your cluster's location
```

## Common Issues

1. **Cluster not found**: Make sure `gke_cluster_location` matches exactly
   - Regional clusters use region: `europe-west4`
   - Zonal clusters use zone: `europe-west4-a`

2. **Connection refused**: Ensure you have cluster credentials:
   ```bash
   gcloud container clusters get-credentials CLUSTER_NAME --location=LOCATION
   ```

3. **Permission denied**: Check your GCP IAM permissions:
   - `roles/container.admin` or `roles/container.clusterAdmin`
   - `roles/iam.serviceAccountAdmin`

## Verification

After deployment, verify everything works:

```bash
# Check cluster
kubectl get nodes

# Check monitoring namespace
kubectl get namespace spacelift-monitoring

# Check pods
kubectl get pods -n spacelift-monitoring

# Port-forward to Grafana
kubectl port-forward -n spacelift-monitoring svc/prometheus-grafana 3000:80
# Visit http://localhost:3000
```

## Troubleshooting

If you see "cluster not found" errors, check:

1. Current project: `gcloud config get-value project`
2. Available clusters: `gcloud container clusters list`
3. Cluster details: `gcloud container clusters describe CLUSTER_NAME --location=LOCATION`