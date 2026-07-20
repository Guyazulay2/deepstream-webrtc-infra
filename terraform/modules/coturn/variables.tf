variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_id" { type = string }

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "realm" {
  type        = string
  description = "TURN realm (e.g. turn.yourdomain.com)"
}

variable "key_pair_name" {
  type        = string
  default     = ""
  description = "EC2 key pair for SSH (leave empty if not needed)"
}

variable "ssh_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Restrict SSH to your IP"
}

variable "tags" {
  type    = map(string)
  default = {}
}
