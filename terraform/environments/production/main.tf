provider "aws" {
  region = var.aws_region
  default_tags { tags = local.tags }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
  }
}

# ─── VPC ─────────────────────────────────────────────────────────────────────
module "vpc" {
  source               = "../../modules/vpc"
  name                 = var.cluster_name
  cluster_name         = var.cluster_name
  region               = var.aws_region
  enable_flow_logs     = true
  enable_vpc_endpoints = false  # set true for production (adds ~$45/mo)
  tags                 = local.tags
}

# ─── EKS ─────────────────────────────────────────────────────────────────────
module "eks" {
  source       = "../../modules/eks"
  cluster_name = var.cluster_name
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  # Restrict kubectl endpoint to your IP/VPN — use "0.0.0.0/0" only during setup
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  tags = local.tags
}

# ─── ECR ─────────────────────────────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"
  name   = "deepstream-webrtc-klv"
  tags   = local.tags
}

# ─── IAM (GitHub OIDC — no stored Access Keys) ───────────────────────────────
module "iam" {
  source       = "../../modules/iam"
  project      = "deepstream-webrtc"
  cluster_name = var.cluster_name
  github_org   = var.github_org
  github_repo  = var.github_repo
  aws_region   = var.aws_region
  tags         = local.tags
}

# ─── COTURN (WebRTC TURN relay — EC2 with fixed Elastic IP) ──────────────────
module "coturn" {
  source           = "../../modules/coturn"
  name             = var.cluster_name
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0]
  realm            = var.turn_realm
  region           = var.aws_region
  tags             = local.tags
}

# ─── ArgoCD (GitOps CD — watches Helm chart in app repo) ─────────────────────
module "argocd" {
  source        = "../../modules/argocd"
  project       = "deepstream-webrtc"
  cluster_name  = var.cluster_name
  app_repo_url  = "https://github.com/${var.github_org}/${var.github_repo}.git"
  app_helm_path = "helm/deepstream-webrtc"
  app_namespace = "deepstream-webrtc"
  hostname      = var.argocd_hostname
  acm_cert_arn  = var.acm_cert_arn
  tags          = local.tags

  depends_on = [module.eks]
}
