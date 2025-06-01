# This is a high-level modular Terraform script for the requested infrastructure

# Required providers
provider "aws" {
  region = var.aws_region
}

# ==================== NETWORKING ====================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "webapp-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_flow_log        = true
  flow_log_max_aggregation_interval = 60
  flow_log_traffic_type  = "ALL"
  flow_log_destination_type = "cloud-watch-logs"
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  tags = {
    Project = "webapp"
  }
}

# ==================== BASTION ====================
module "bastion" {
  source  = "cloudposse/ec2-bastion-server/aws"
  version = "1.0.0"

  instance_type       = "t3.micro"
  vpc_id              = module.vpc.vpc_id
  subnet_id           = module.vpc.public_subnets[0]
  key_name            = var.bastion_key_name
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}

# ==================== ACM Certificates ====================
resource "aws_acm_certificate" "alb" {
  domain_name       = var.alb_domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "eks" {
  domain_name       = var.eks_domain
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

# ==================== ECR ====================
module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "1.5.0"

  repository_name = "webapp-repo"
  create_lifecycle_policy = true
}

# ==================== ROUTE 53 ====================
resource "aws_route53_record" "alb" {
  zone_id = var.route53_zone_id
  name    = var.alb_domain
  type    = "A"
  alias {
    name                   = aws_lb.webapp.dns_name
    zone_id                = aws_lb.webapp.zone_id
    evaluate_target_health = true
  }
}

# ==================== SECRETS MANAGER ====================
resource "aws_secretsmanager_secret" "app_secret" {
  name = "webapp-secret"
}

# ==================== EKS CLUSTERS ====================
module "eks_tools" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.4.0"
  cluster_name    = "tools-cluster"
  cluster_version = "1.29"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  eks_managed_node_groups = {
    default = {
      desired_capacity = 2
      instance_types   = ["t3.medium"]
    }
  }
}

module "eks_webapp" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.4.0"
  cluster_name    = "webapp-cluster"
  cluster_version = "1.29"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  eks_managed_node_groups = {
    default = {
      desired_capacity = 3
      instance_types   = ["t3.large"]
    }
  }
}

# ==================== IAM Policies and Roles ====================
resource "aws_iam_policy" "alb_ingress_controller" {
  name        = "ALBIngressControllerIAMPolicy"
  description = "IAM policy for AWS ALB Ingress Controller"
  policy      = file("alb_ingress_policy.json")
}

resource "aws_iam_policy" "argocd" {
  name        = "ArgoCDPolicy"
  description = "IAM policy for ArgoCD"
  policy      = file("argocd_policy.json")
}

resource "aws_iam_policy" "gitea" {
  name        = "GiteaPolicy"
  description = "IAM policy for Gitea"
  policy      = file("gitea_policy.json")
}

resource "aws_iam_policy" "github_runner" {
  name        = "GitHubRunnerPolicy"
  description = "IAM policy for GitHub Runner"
  policy      = file("github_runner_policy.json")
}

module "alb_ingress_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.30.0"

  name = "alb-ingress-controller"

  create_role = true
  role_name   = "alb-ingress-controller"

  provider_url = module.eks_webapp.oidc_provider
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:alb-ingress-controller"]

  policy_arns = [aws_iam_policy.alb_ingress_controller.arn]
}

module "argocd_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.30.0"

  name = "argocd-server"

  create_role = true
  role_name   = "argocd-server"

  provider_url = module.eks_tools.oidc_provider
  oidc_fully_qualified_subjects = ["system:serviceaccount:argocd:argocd-server"]

  policy_arns = [aws_iam_policy.argocd.arn]
}

module "gitea_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.30.0"

  name = "gitea"

  create_role = true
  role_name   = "gitea"

  provider_url = module.eks_tools.oidc_provider
  oidc_fully_qualified_subjects = ["system:serviceaccount:gitea:gitea"]

  policy_arns = [aws_iam_policy.gitea.arn]
}

module "github_runner_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.30.0"

  name = "github-runner"

  create_role = true
  role_name   = "github-runner"

  provider_url = module.eks_tools.oidc_provider
  oidc_fully_qualified_subjects = ["system:serviceaccount:github:runner"]

  policy_arns = [aws_iam_policy.github_runner.arn]
}

# Helm provider for Helm chart deployments
provider "helm" {
  kubernetes {
    host                   = module.eks_tools.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_tools.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.tools.token
  }
  alias = "tools"
}

provider "helm" {
  kubernetes {
    host                   = module.eks_webapp.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_webapp.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.webapp.token
  }
  alias = "webapp"
}

# Get EKS cluster auth tokens
data "aws_eks_cluster_auth" "tools" {
  name = module.eks_tools.cluster_name
}

data "aws_eks_cluster_auth" "webapp" {
  name = module.eks_webapp.cluster_name
}

# Deploy ArgoCD via Helm to tools cluster
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  create_namespace = true
  service_account = "argocd-server"
  values = [
    <<EOF
server:
  serviceAccount:
    create: false
    name: argocd-server
EOF
  ]
  provider = helm.tools
}

# Deploy Gitea via Helm to tools cluster
resource "helm_release" "gitea" {
  name       = "gitea"
  namespace  = "gitea"
  repository = "https://dl.gitea.io/charts/"
  chart      = "gitea"
  version    = "10.2.0"
  create_namespace = true
  service_account = "gitea"
  values = [
    <<EOF
serviceAccount:
  create: false
  name: gitea
persistence:
  enabled: true
  size: 10Gi
EOF
  ]
  provider = helm.tools
}

# Deploy GitHub Runner Controller via Helm to tools cluster
resource "helm_release" "github_runner_controller" {
  name       = "actions-runner-controller"
  namespace  = "github"
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart      = "actions-runner-controller"
  version    = "0.24.1"
  create_namespace = true
  service_account = "runner"
  values = [
    <<EOF
serviceAccount:
  create: false
  name: runner
EOF
  ]
  provider = helm.tools
}

# Deploy AWS ALB Ingress Controller to webapp cluster
resource "helm_release" "alb_ingress" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.1"
  create_namespace = false
  service_account = "alb-ingress-controller"
  values = [
    <<EOF
clusterName: webapp-cluster
serviceAccount:
  create: false
  name: alb-ingress-controller
region: ${var.aws_region}
vpcId: ${module.vpc.vpc_id}
EOF
  ]
  provider = helm.webapp
}
