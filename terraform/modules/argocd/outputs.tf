output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "access_instructions" {
  value = var.hostname != "" ? "ArgoCD UI: https://${var.hostname}" : "kubectl port-forward svc/argocd-server -n argocd 8080:443  →  https://localhost:8080"
}
