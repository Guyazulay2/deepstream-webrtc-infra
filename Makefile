##############################################################################
# deepstream-webrtc — Infra Makefile
# שימוש: make <target>
##############################################################################

AWS_REGION   ?= us-east-1
CLUSTER_NAME ?= deepstream-webrtc
GITHUB_ORG   ?= Guyazulay2
TF_DIR        = terraform/environments/production
BACKEND_HCL   = terraform/backend.hcl

.PHONY: help check-tools bootstrap tf-init tf-plan tf-apply tf-destroy \
        kubeconfig argocd-setup push-secrets

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

check-tools: ## בדוק שכל הכלים מותקנים
	@command -v aws       >/dev/null || (echo "aws cli missing"    && exit 1)
	@command -v terraform >/dev/null || (echo "terraform missing"  && exit 1)
	@command -v kubectl   >/dev/null || (echo "kubectl missing"    && exit 1)
	@command -v helm      >/dev/null || (echo "helm missing"       && exit 1)
	@aws sts get-caller-identity >/dev/null || (echo "aws not configured" && exit 1)
	@echo "OK"

# ─── Bootstrap (פעם אחת בלבד) ────────────────────────────────────────────────
bootstrap: check-tools ## [ONCE] צור S3 bucket לTerraform state
	cd terraform/bootstrap && terraform init && terraform apply -auto-approve
	@echo "Copy s3_bucket_name output → terraform/backend.hcl"

# ─── Terraform ────────────────────────────────────────────────────────────────
tf-init: ## terraform init
	cd $(TF_DIR) && terraform init -backend-config=../../backend.hcl

tf-plan: tf-init ## terraform plan — ראה מה ישתנה
	cd $(TF_DIR) && terraform plan -var="github_org=$(GITHUB_ORG)"

tf-apply: tf-init ## terraform apply — צור/עדכן תשתית
	cd $(TF_DIR) && terraform apply -var="github_org=$(GITHUB_ORG)"

tf-destroy: tf-init ## terraform destroy — הרוס הכל (עצור חיובים)
	cd $(TF_DIR) && terraform destroy -var="github_org=$(GITHUB_ORG)"

tf-output: ## הצג outputs (ECR URL, Role ARN, TURN IP)
	@cd $(TF_DIR) && terraform output

# ─── Cluster ──────────────────────────────────────────────────────────────────
kubeconfig: ## עדכן kubeconfig להתחבר ל-EKS
	aws eks update-kubeconfig \
	  --name $(CLUSTER_NAME) \
	  --region $(AWS_REGION)
	kubectl get nodes

argocd-setup: ## החל ArgoCD Application + K8s manifests
	@echo "=== Applying K8s cluster resources ==="
	kubectl apply -f k8s/namespaces/
	kubectl apply -f k8s/network-policies/
	kubectl apply -f k8s/external-secrets/
	@echo "=== Applying ArgoCD Application ==="
	kubectl apply -f argocd/apps/deepstream-webrtc.yaml
	@echo "=== ArgoCD admin password ==="
	@kubectl get secret argocd-initial-admin-secret -n argocd \
	  -o jsonpath="{.data.password}" | base64 -d && echo
	@echo "Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"

# ─── Secrets ──────────────────────────────────────────────────────────────────
push-secrets: ## דחוף secrets/production.env לAWS Secrets Manager
	@test -f secrets/production.env || \
	  (echo "Create secrets/production.env first (copy from .example)" && exit 1)
	@PAYLOAD=$$(grep -v '^#' secrets/production.env | grep '=' | \
	  awk -F'=' '{printf "\"%-s\":\"%s\",", $$1, $$2}' | sed 's/,$$//') ; \
	  aws secretsmanager create-secret \
	    --name "deepstream-webrtc/turn" \
	    --secret-string "{$${PAYLOAD}}" \
	    --region $(AWS_REGION) 2>/dev/null || \
	  aws secretsmanager update-secret \
	    --secret-id "deepstream-webrtc/turn" \
	    --secret-string "{$${PAYLOAD}}" \
	    --region $(AWS_REGION)
	@echo "Secrets pushed"
