variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "deepstream-webrtc"
}

variable "github_org" {
  description = "GitHub org or username (e.g. guyazulay2)"
}

variable "github_repo" {
  default = "deepstream-webrtc-klv"
}

variable "turn_realm" {
  default     = "deepstream-webrtc.local"
  description = "COTURN realm — use your domain (e.g. turn.yourdomain.com)"
}

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Restrict kubectl endpoint to your IP. e.g. [\"1.2.3.4/32\"]"
}

variable "argocd_hostname" {
  default     = ""
  description = "ArgoCD UI hostname (e.g. argocd.yourdomain.com). Leave empty to use port-forward."
}

variable "acm_cert_arn" {
  default     = ""
  description = "ACM certificate ARN for HTTPS (needed if argocd_hostname is set)"
}

locals {
  tags = {
    Project     = "deepstream-webrtc"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
