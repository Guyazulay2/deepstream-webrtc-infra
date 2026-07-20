output "ecr_url" { value = module.ecr.repository_url }
output "cluster_name" { value = module.eks.cluster_name }
output "github_actions_role_arn" { value = module.iam.github_actions_role_arn }
output "turn_public_ip" { value = module.coturn.public_ip }
output "turn_secret_arn" { value = module.coturn.turn_secret_arn }

output "turn_secret" {
  value       = module.coturn.turn_secret_value
  sensitive   = true
  description = "Run: terraform output -raw turn_secret  → add to secrets/production.env as TURN_SECRET"
}

output "kubectl_config_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "next_steps" {
  value = <<-EOT
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Terraform apply complete. Next steps:

    1. Connect kubectl:
       aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}

    2. Add GitHub secret (ONE TIME):
       Go to GitHub → Settings → Secrets → Actions
       Name: AWS_GITHUB_ACTIONS_ROLE_ARN
       Value: ${module.iam.github_actions_role_arn}

    3. Build & push first image:
       cd ../../..
       make build-push ECR_URL=${module.ecr.repository_url}

    4. Deploy app:
       make deploy ECR_URL=${module.ecr.repository_url}

    5. Add TURN secret to AWS Secrets Manager:
       terraform output -raw turn_secret
       # Copy the value → add to secrets/production.env as TURN_SECRET
       # Then: make push-secrets  (also sets TURN_HOST=${module.coturn.public_ip})

    6. Get your public URL:
       kubectl get ingress -n deepstream-webrtc
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EOT
}
