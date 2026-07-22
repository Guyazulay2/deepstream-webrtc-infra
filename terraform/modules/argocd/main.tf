# ─── ArgoCD via Helm ─────────────────────────────────────────────────────────
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = var.chart_version
  wait             = true
  timeout          = 600

  values = [yamlencode({
    global = {
      domain = var.hostname
    }
    server = {
      service = { type = "ClusterIP" }
      ingress = var.hostname != "" ? {
        enabled = true
        annotations = {
          "kubernetes.io/ingress.class"                = "alb"
          "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
          "alb.ingress.kubernetes.io/target-type"      = "ip"
          "alb.ingress.kubernetes.io/certificate-arn"  = var.acm_cert_arn
          "alb.ingress.kubernetes.io/ssl-policy"       = "ELBSecurityPolicy-TLS13-1-2-2021-06"
          "alb.ingress.kubernetes.io/backend-protocol" = "HTTPS"
        }
        tls = true
        } : {
        enabled     = false
        annotations = {}
        tls         = false
      }
    }
    configs = {
      params = {
        # Run ArgoCD behind ALB — disable built-in TLS termination
        "server.insecure" = var.hostname != ""
      }
    }
  })]
}

# ArgoCD Application is applied separately after the cluster is ready:
#   kubectl apply -f argocd/apps/deepstream-webrtc.yaml
# This avoids the chicken-and-egg problem where Terraform tries to connect
# to a cluster that doesn't exist yet during plan.

# ─── Admin password stored in Secrets Manager (retrieve after first apply) ───
# kubectl get secret argocd-initial-admin-secret -n argocd \
#   -o jsonpath="{.data.password}" | base64 -d
resource "aws_secretsmanager_secret" "argocd_url" {
  name                    = "${var.project}/argocd/ui-url"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "argocd_url" {
  secret_id     = aws_secretsmanager_secret.argocd_url.id
  secret_string = var.hostname != "" ? "https://${var.hostname}" : "use: kubectl port-forward svc/argocd-server -n argocd 8080:443"
}
