###############################################################################
# iam_oidc.tf
# Phase 3 — GitHub Actions ↔ AWS trust via OpenID Connect (OIDC)
#
# How OIDC works here (no secrets needed):
#   1. GitHub Actions generates a short-lived JWT signed by GitHub's OIDC IdP.
#   2. AWS STS verifies the JWT against the OIDC thumbprint registered below.
#   3. If the "sub" claim matches the allowed repo/branch condition, AWS issues
#      a temporary credential set (15-minute TTL) via AssumeRoleWithWebIdentity.
#   4. The workflow uses those temp creds to log in to ECR and push images.
#   → Zero long-lived AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY secrets.
###############################################################################

###############################################################################
# GitHub OIDC Identity Provider
# AWS needs to trust GitHub as a token issuer exactly once per account.
# If you already have this provider in your account (e.g. from another project)
# replace this resource with a data source:
#   data "aws_iam_openid_connect_provider" "github" {
#     url = "https://token.actions.githubusercontent.com"
#   }
# and update the assume-role policy to reference data.aws_iam_openid_connect_provider.github.arn
###############################################################################
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # AWS requires at least one audience value; GitHub Actions always sends this.
  client_id_list = ["sts.amazonaws.com"]

  # SHA-1 thumbprint of GitHub's OIDC certificate.
  # GitHub publishes this at:
  # https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
  # AWS actually ignores the thumbprint for github.com (it validates via its
  # own trust store), but the field is still required by the API.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${var.project_name}-github-oidc-provider"
  }
}

###############################################################################
# IAM Policy — scoped ECR permissions
# Principle of least privilege:
#   • GetAuthorizationToken  → docker login  (account-level, no resource scope)
#   • Batch/layer actions    → scoped to online-boutique/* repos only
###############################################################################
resource "aws_iam_policy" "github_actions_ecr" {
  name        = "${var.project_name}-github-actions-ecr-policy"
  description = "Allows GitHub Actions to authenticate with ECR and push/pull images for ${var.project_name}."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR login — must be *, cannot be scoped to a specific repo
      {
        Sid      = "AllowECRLogin"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      # Push + pull — scoped to ONLY the online-boutique/* repositories
      {
        Sid    = "AllowImagePushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.project_name}/*"
      },
    ]
  })
}

###############################################################################
# IAM Role — assumed by GitHub Actions via OIDC
###############################################################################
resource "aws_iam_role" "github_actions" {
  name        = "${var.project_name}-github-actions-role"
  description = "Assumed by GitHub Actions (OIDC) to build and push Docker images to ECR."

  # Trust policy — the "who can assume this role" document.
  # The StringLike condition on the `sub` claim is the security gate:
  #   token.actions.githubusercontent.com:sub must match
  #   repo:GaganPal27/online-boutique-aws:*
  #
  # The trailing :* allows ANY branch/tag/PR to assume the role.
  # To lock it to main only, change to:
  #   repo:GaganPal27/online-boutique-aws:ref:refs/heads/main
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubOIDCTrust"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Scoped to YOUR repo only — other repos in GitHub cannot assume this role.
            "token.actions.githubusercontent.com:sub" = "repo:GaganPal27/online-boutique-aws:*"
          }
        }
      },
    ]
  })

  # Temporary credentials issued by STS expire after 1 hour.
  # A docker push of a large image can take time — 1h is safer than the 15m default.
  max_session_duration = 3600

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# Attach the scoped ECR policy to the role.
resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

