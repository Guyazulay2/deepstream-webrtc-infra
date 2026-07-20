variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "enable_flow_logs" {
  type        = bool
  default     = true
  description = "Send VPC flow logs to CloudWatch (30-day retention)"
}

variable "enable_vpc_endpoints" {
  type        = bool
  default     = false
  description = "Create Interface VPC Endpoints for ECR, STS, SSM (~$45/mo). Set true in production to remove internet dependency."
}

variable "tags" {
  type    = map(string)
  default = {}
}
