variable "project" { type = string }
variable "cluster_name" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string }

variable "infra_repo" {
  description = "GitHub repo running the Terraform workflow (also allowed to assume this role)"
  type        = string
  default     = "deepstream-webrtc-infra"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
