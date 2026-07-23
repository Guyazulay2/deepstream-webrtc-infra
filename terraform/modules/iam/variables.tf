variable "project" { type = string }
variable "cluster_name" { type = string }
variable "github_org" { type = string }
variable "github_repo" { type = string }

variable "infra_repo" {
  description = "GitHub repo running the Terraform workflow (also allowed to assume this role)"
  type        = string
  default     = "deepstream-webrtc-infra"
}

# infra_repo was renamed, so GitHub's OIDC sub claim for it embeds immutable
# org/repo IDs (repo:ORG@orgId/REPO@repoId:*) instead of the plain name form.
# Values confirmed from CloudTrail AssumeRoleWithWebIdentity events.
variable "infra_repo_github_org_id" {
  type    = string
  default = "59178662"
}

variable "infra_repo_github_id" {
  type    = string
  default = "1306981152"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
