terraform {
  required_version = ">= 1.3.0"
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Providers Configuration
# -----------------------------------------------------------------------------
provider "kind" {}

provider "kubernetes" {
  host                   = kind_cluster.local_cluster.endpoint
  client_certificate     = kind_cluster.local_cluster.client_certificate
  client_key             = kind_cluster.local_cluster.client_key
  cluster_ca_certificate = kind_cluster.local_cluster.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.local_cluster.endpoint
    client_certificate     = kind_cluster.local_cluster.client_certificate
    client_key             = kind_cluster.local_cluster.client_key
    cluster_ca_certificate = kind_cluster.local_cluster.cluster_ca_certificate
  }
}

# -----------------------------------------------------------------------------
# KinD Cluster Resource (1 Control Plane, 2 Workers)
# -----------------------------------------------------------------------------
resource "kind_cluster" "local_cluster" {
  name            = "kind" # Requested cluster name
  node_image      = "kindest/node:v1.31.0"
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      disable_default_cni = true
      kube_proxy_mode     = "none" # native eBPF routing via Cilium
    }

    # 1. Control Plane Node
    node {
      role = "control-plane"
    }

    # 2. Worker Node 1
    node {
      role = "worker"
    }

    # 3. Worker Node 2
    node {
      role = "worker"
    }
  }
}

# -----------------------------------------------------------------------------
# Install Cilium CNI (via Helm)
# -----------------------------------------------------------------------------
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io"
  #chart      = "./cilium"
  chart      = "cilium"
  version    = "1.16.1"
  namespace  = "kube-system"

  depends_on = [kind_cluster.local_cluster]

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }
  set {
    name  = "k8sServiceHost"
    value = "kind-control-plane" # Matches container name format: "${cluster_name}-control-plane"
  }
  set {
    name  = "k8sServicePort"
    value = "6443"
  }
  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }
  set {
    name  = "bpf.masquerade"
    value = "true"
  }
  set {
    name  = "operator.replicas"
    value = "1"
  }
  # --- CRITICAL FLAGS FOR MAC M1 DOCKER ENVIRONMENT ---
  set {
    name  = "cgroup.autoMount.enabled"
    value = "true"
  }
  set {
    name  = "bpf.autoMount.enabled"
    value = "true"
  }
}

# -----------------------------------------------------------------------------
# Install Tetragon Security Observability (via Helm)
# -----------------------------------------------------------------------------
resource "helm_release" "tetragon" {
  name       = "tetragon"
  repository = "https://helm.cilium.io"
  chart      = "tetragon"
  #chart      = "./tetragon"
  version    = "1.1.2"
  namespace  = "kube-system"

  depends_on = [helm_release.cilium]
}

# -----------------------------------------------------------------------------
# Install Kyverno Policy Engine (via Helm)
# -----------------------------------------------------------------------------
resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno/"
  #chart            = "./kyverno"
  chart            = "kyverno"
  version          = "3.3.0"
  namespace        = "kyverno"
  create_namespace = true

  depends_on = [helm_release.cilium]

  # Local Mac Resource conservation (1 replica per controller component)
  set {
    name  = "admissionController.replicas"
    value = "1"
  }
  set {
    name  = "backgroundController.replicas"
    value = "1"
  }
  set {
    name  = "cleanupController.replicas"
    value = "1"
  }
  set {
    name  = "reportsController.replicas"
    value = "1"
  }
}
