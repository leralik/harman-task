variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "bastion_key_name" {
  description = "SSH key name for the bastion host"
  type        = string
}

variable "alb_domain" {
  description = "Domain name for the ALB"
  type        = string
}

variable "eks_domain" {
  description = "Domain name for the EKS cluster"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "eks_tools_cluster_name" {
  description = "Name for the tools EKS cluster"
  type        = string
  default     = "tools-cluster"
}

variable "eks_webapp_cluster_name" {
  description = "Name for the webapp EKS cluster"
  type        = string
  default     = "webapp-cluster"
}

variable "eks_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.29"
}

variable "tools_node_instance_type" {
  description = "Instance type for tools EKS node group"
  type        = string
  default     = "t3.medium"
}

variable "tools_node_desired_capacity" {
  description = "Desired node count for tools EKS"
  type        = number
  default     = 2
}

variable "webapp_node_instance_type" {
  description = "Instance type for webapp EKS node group"
  type        = string
  default     = "t3.large"
}

variable "webapp_node_desired_capacity" {
  description = "Desired node count for webapp EKS"
  type        = number
  default     = 3
}

variable "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "gitea_chart_version" {
  description = "Version of the Gitea Helm chart"
  type        = string
  default     = "10.2.0"
}

variable "github_runner_chart_version" {
  description = "Version of the GitHub Runner Controller Helm chart"
  type        = string
  default     = "0.24.1"
}

variable "alb_ingress_chart_version" {
  description = "Version of the AWS ALB Ingress Controller Helm chart"
  type        = string
  default     = "1.7.1"
}