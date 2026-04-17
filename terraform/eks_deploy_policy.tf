###############################################################################
# eks_deploy_policy.tf  —  Phase 5 addition
#
# The deploy.yml workflow needs to call:
#   aws eks update-kubeconfig  (eks:DescribeCluster)
#   kubectl / helm             (Kubernetes API via kubeconfig — covered by
#                               enable_cluster_creator_admin_permissions)
#
# This file attaches a minimal EKS read policy to the EXISTING GitHub Actions
# role created in iam_oidc.tf.  No new role is created.
###############################################################################

resource "aws_iam_policy" "github_actions_eks" {
  name        = "${var.project_name}-github-actions-eks-policy"
  description = "Allows GitHub Actions deploy workflow to describe the EKS cluster and update kubeconfig."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowEKSDescribe"
        Effect   = "Allow"
        Action   = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.project_name}-eks"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_eks" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_eks.arn
}

###############################################################################
# Output — used as GitHub secret AWS_LBC_ROLE_ARN in deploy.yml
###############################################################################
output "aws_lbc_role_arn_for_github_secret" {
  description = "Add this as GitHub repo secret: AWS_LBC_ROLE_ARN"
  value       = module.aws_lb_controller_irsa.iam_role_arn
}
