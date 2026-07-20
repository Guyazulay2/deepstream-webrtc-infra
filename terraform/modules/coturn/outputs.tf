output "public_ip" { value = aws_eip.coturn.public_ip }
output "public_dns" { value = aws_eip.coturn.public_dns }
output "turn_secret_arn" { value = aws_secretsmanager_secret.turn_secret.arn }
output "turn_host" { value = aws_eip.coturn.public_ip }

output "turn_secret_value" {
  value       = random_password.turn_secret.result
  sensitive   = true
  description = "Add to AWS Secrets Manager key 'deepstream-webrtc/production' as TURN_SECRET"
}
