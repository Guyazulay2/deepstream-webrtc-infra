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
  default = "1.29"
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
