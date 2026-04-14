###############################################################################
# outputs.tf  —  Phase 4
#
# Single file for ALL Terraform outputs across the project.
# Centralising outputs here means:
#   • No need to hunt across vpc.tf / eks.tf / ecr.tf for values.
#   • CI/CD scripts and Helm steps can run a single
#     `terraform output -json` to get everything they need.
###############################################################################

###############################################################################
# ── VPC ──────────────────────────────────────────────────────────────────────
###############################################################################
output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the 3 public subnets (NAT Gateways + ALBs)."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the 3 private subnets (EKS nodes)."
  value       = module.vpc.private_subnets
}

###############################################################################
# ── EKS ──────────────────────────────────────────────────────────────────────
###############################################################################

output "cluster_name" {
  description = "EKS cluster name. Use in helm install --set ... or aws eks commands."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server URL. Used by the Kubernetes and Helm Terraform providers."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA bundle for the cluster. Keep this secret."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster."
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — needed when creating additional IRSA roles."
  value       = module.eks.oidc_provider_arn
}

# ── The most important output for day-to-day use ────────────────────────────
output "configure_kubectl" {
  description = <<-EOT
    Run this command to configure kubectl and connect to the cluster:

      aws eks update-kubeconfig --region <REGION> --name <CLUSTER_NAME>

    After running it, verify with:

      kubectl get nodes
      kubectl get pods -A
  EOT
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

###############################################################################
# ── IRSA Role ARNs ───────────────────────────────────────────────────────────
# These are passed as Helm values in Phase 4 (AWS LBC, EBS CSI).
###############################################################################
output "aws_lb_controller_role_arn" {
  description = "IAM Role ARN for the AWS Load Balancer Controller. Pass to Helm in Phase 4."
  value       = module.aws_lb_controller_irsa.iam_role_arn
}

output "ebs_csi_role_arn" {
  description = "IAM Role ARN for the EBS CSI Driver."
  value       = module.ebs_csi_irsa.iam_role_arn
}

output "vpc_cni_role_arn" {
  description = "IAM Role ARN for the VPC CNI plugin."
  value       = module.vpc_cni_irsa.iam_role_arn
}

###############################################################################
# ── ECR ──────────────────────────────────────────────────────────────────────
###############################################################################
output "ecr_registry_url" {
  description = "ECR registry base URL for docker login."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "ecr_repository_urls" {
  description = "Map of service name → full ECR repository URL."
  value       = { for k, repo in aws_ecr_repository.microservices : k => repo.repository_url }
}

###############################################################################
# ── GitHub Actions IAM ───────────────────────────────────────────────────────
###############################################################################
output "github_actions_role_arn" {
  description = "IAM Role ARN to store as the AWS_ROLE_ARN GitHub repository secret."
  value       = aws_iam_role.github_actions.arn
}

###############################################################################
# ── Quick-reference summary ──────────────────────────────────────────────────
# Run `terraform output summary` for a single human-readable block covering
# everything you need for the next phase.
###############################################################################
output "summary" {
  description = "Human-readable quick-reference for all key values."
  value = <<-EOT

    ╔══════════════════════════════════════════════════════════════╗
    ║          Online Boutique AWS — Infrastructure Summary        ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  CLUSTER                                                     ║
    ║  Name    : ${module.eks.cluster_name}
    ║  Version : ${module.eks.cluster_version}
    ║  Endpoint: ${module.eks.cluster_endpoint}
    ║                                                              ║
    ║  KUBECTL SETUP                                               ║
    ║  aws eks update-kubeconfig \                                 ║
    ║    --region ${var.aws_region} \                                      ║
    ║    --name ${module.eks.cluster_name}
    ║                                                              ║
    ║  ECR REGISTRY                                                ║
    ║  ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
    ║                                                              ║
    ║  GITHUB ACTIONS ROLE                                         ║
    ║  ${aws_iam_role.github_actions.arn}
    ║                                                              ║
    ║  AWS LBC ROLE (needed for Phase 4 Helm)                      ║
    ║  ${module.aws_lb_controller_irsa.iam_role_arn}
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}
