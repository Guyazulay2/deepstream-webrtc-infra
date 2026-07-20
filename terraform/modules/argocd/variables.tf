variable "project" {
  type        = string
  description = "Project name for resource naming"
}

variable "cluster_name" {
  type = string
}

variable "chart_version" {
  type        = string
  default     = "7.3.11"
  description = "argo-cd Helm chart version"
}

variable "hostname" {
  type        = string
  default     = ""
  description = "ArgoCD UI hostname (e.g. argocd.yourdomain.com). Leave empty to access via port-forward."
}

variable "acm_cert_arn" {
  type        = string
  default     = ""
  description = "ACM cert ARN for HTTPS on ArgoCD ALB ingress"
}

variable "app_repo_url" {
  type        = string
  description = "GitHub repo URL for the app Helm chart (e.g. https://github.com/guyazulay2/deepstream-webrtc-klv.git)"
}

variable "app_helm_path" {
  type        = string
  default     = "helm/deepstream-webrtc"
  description = "Path inside the app repo where the Helm chart lives"
}

variable "app_namespace" {
  type        = string
  default     = "deepstream-webrtc"
  description = "K8s namespace to deploy the application into"
}

variable "tags" {
  type    = map(string)
  default = {}
}
