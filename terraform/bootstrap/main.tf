# ─── Bootstrap ─────────────────────────────────────────────────────────────────
# פרויקט bootstrap = "ה-Terraform שמכין את Terraform"
# מריצים פעם אחת ידנית: terraform init && terraform apply
# אחרי זה — כל ה-state של שאר ה-environments נשמר כאן
#
# מריצים עם: cd infrastructure/terraform/bootstrap && terraform apply

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # bootstrap שומר state מקומית בלבד — זה בסדר כי רץ פעם אחת
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" { default = "us-east-1" }
variable "project" { default = "deepstream-webrtc" }

# ─── S3 Bucket for Terraform State ────────────────────────────────────────────
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"

  # מנע מחיקה בטעות של ה-state
  lifecycle { prevent_destroy = true }

  tags = { Name = "terraform-state", Project = var.project }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
  # versioning = כל שינוי ב-state נשמר → אפשר לחזור לכל גרסה קודמת
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms" # מוצפן ב-KMS
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─── DynamoDB Table for State Locking ─────────────────────────────────────────
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "terraform-state-lock", Project = var.project }
}

data "aws_caller_identity" "current" {}

output "s3_bucket_name" { value = aws_s3_bucket.tfstate.bucket }
output "dynamodb_table_name" { value = aws_dynamodb_table.tfstate_lock.name }
output "init_command" {
  value = "terraform init -backend-config=bucket=${aws_s3_bucket.tfstate.bucket} -backend-config=key=prod/terraform.tfstate -backend-config=region=${var.aws_region}"
}
