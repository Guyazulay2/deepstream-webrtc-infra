variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "kubernetes_version" {
  type    = string
  # Was bumped to 1.35, but that replaces the node group (brief downtime) —
  # holding at 1.32 for now so it can be applied deliberately, decoupled from
  # the CI access-entry fix.
  default = "1.32"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_min" {
  type    = number
  default = 1
}

variable "node_max" {
  type    = number
  default = 4
}

variable "node_desired" {
  type    = number
  default = 2
}

variable "node_disk_size" {
  type        = number
  default     = 50
  description = "Root EBS volume size (GB) — encrypted with KMS"
}

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Restrict kubectl access to these CIDRs. Set to your office/VPN IP for production."
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "github_actions_role_arn" {
  description = "IAM role assumed by CI (terraform apply) — granted cluster-admin EKS access so helm_release/kubernetes providers can reach the API server"
  type        = string
  default     = ""
}
