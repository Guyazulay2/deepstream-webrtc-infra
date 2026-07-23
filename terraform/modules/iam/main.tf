# ─── GitHub Actions OIDC ───────────────────────────────────────────────────────
# לראיון: OIDC = GitHub מנפיק JWT token לכל job.
# AWS מאמת את ה-token מול ה-OIDC provider במקום לשמור Access Keys.
# אפס credentials בCI/CD → אפס סיכון לדליפה.

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint רשמי של GitHub OIDC (לא משתנה)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

# ─── IAM Role ─ GitHub Actions ─────────────────────────────────────────────────
resource "aws_iam_role" "github_actions" {
  name = "${var.project}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # מגביל לrepos הספציפיים שלך בלבד — אבטחה קריטית!
          # app repo (build/push/deploy) + infra repo (terraform plan/apply)
          #
          # deepstream-webrtc-infra was renamed at some point, so GitHub embeds
          # immutable org/repo IDs in the sub claim for it (anti-spoofing after
          # a rename): repo:ORG@orgId/REPO@repoId:... instead of the plain form.
          # Confirmed via CloudTrail AssumeRoleWithWebIdentity events.
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${var.github_repo}:*",
            "repo:${var.github_org}/${var.infra_repo}:*",
            "repo:${var.github_org}@${var.infra_repo_github_org_id}/${var.infra_repo}@${var.infra_repo_github_id}:*",
          ]
        }
      }
    }]
  })

  tags = var.tags
}

# ─── Permissions for GitHub Actions ───────────────────────────────────────────
# ECR: push images
resource "aws_iam_role_policy_attachment" "github_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

# Terraform (infra repo): full-stack plan/apply needs to read/write EC2 (VPC,
# security groups, launch templates, coturn instance), EKS (cluster, node
# groups, addons — AWS ships no narrower managed policy for an external
# caller to manage EKS via API), KMS, and Secrets Manager. There's no tighter
# official combo than PowerUserAccess (everything except IAM) + IAMFullAccess
# (Terraform creates/attaches IRSA roles for ebs-csi, alb-controller,
# external-secrets, coturn, and this role itself) — together that's
# effectively admin minus Organizations/Account actions. Since this role is
# shared with the app repo's build/push workflow, that workflow now also
# carries this access even though it only needs ECR push.
resource "aws_iam_role_policy_attachment" "github_terraform_power_user" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "github_terraform_iam" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

# EKS: update kubeconfig + deploy
resource "aws_iam_role_policy" "github_eks" {
  name = "eks-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters", "eks:AccessKubernetesApi"]
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      },
      {
        # Terraform apply: CloudWatch Logs, S3 state, DynamoDB lock
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
          "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"
        ]
        Resource = "*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
