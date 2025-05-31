
# Project Title

HARMAN task end-to-end deployment architecture 


## Author

- leralik

## Task description

You are given a newly created AWS account. Deploy a webservice (in the form of microservice) and make it publicly accessible over the internet. Adopt all possible DevOps & Security best practices. Accompany the end-to-end deployment architecture diagram. Adopt Open Source as much as possible.


## Architecture Components

1. AWS Services:

   EKS: Managed Kubernetes service.

   ALB: Application Load Balancer for routing traffic.

   ECR: Elastic Container Registry for storing Docker images.

   Certificate Manager: For SSL/TLS certificates.

   IAM: Identity and Access Management.

   Security Groups: Virtual firewalls for controlling inbound/outbound traffic.

   Route 53: DNS service.

   NAT Gateway & Internet Gateway: For internet access.

2. DevOps Tools:

   GitHub: Source code repository.

   Gitea: Self-hosted Git service.

   GitHub Runner: For CI/CD pipelines.

   Argo CD: GitOps continuous delivery tool.

## Set Up AWS Infrastructure (terraform)

a. VPC Configuration:

   Create a VPC with public and private subnets across multiple Availability Zones.

   Set up an Internet Gateway and attach it to the VPC.

   Configure a NAT Gateway in a public subnet to allow instances in private subnets to access the internet.

b. Security Groups:

   Define security groups for:

   ALB: Allow HTTPS (443) traffic.

   EKS Nodes: Allow necessary ports (e.g., 443 for Kubernetes API).

c. IAM Roles:

   Create IAM roles with least privilege for:

   EKS Cluster and Nodes.

   Argo CD.

   GitHub Runner.

   External Secrets Operator.

d. Route 53:

   Register a domain .

   Create hosted zones and necessary DNS records for your services.

e. Certificate Manager:

   Request SSL/TLS certificates for your domain via AWS Certificate Manager.

   Validate domain ownership using DNS validation through Route 53.
   
## Provision EKS Cluster

   Use eksctl or Terraform to create an EKS cluster with the configured VPC and subnets.

   Ensure the cluster has the necessary IAM roles and node groups.
   
## Set Up ECR
   Create an ECR repository to store your Docker images.

   Push your microservice Docker image to ECR( HitHub Actions)
   
##  Infrucsture  cluster ( helm charts)

1. Deploy Gitea
   Deploy Gitea in the EKS cluster
   Expose Gitea via an internal service and ingress.


2. Configure GitHub Runner
   
   Deploy a self-hosted GitHub Runner in the EKS cluster
   Configure the runner to Update Kubernetes manifests in Gitea and images in ECR


4. Install Argo CD
5. 
   Deploy Argo CD in the EKS cluster
   Expose Argo CD via an ingress 
   Configure Argo CD to monitor the Gitea repository for Kubernetes manifests. 
   Register the remote app cluster in Argo CD

6. Set Up External Secrets Operator
   Deploy the External Secrets Operator in the EKS cluster.
   Configure it to sync secrets from AWS Secrets Manager to Kubernetes secrets.

## CI/CD Workflow

Flow:

   GitHub → GitHub Runner → ECR & Gitea → Argo CD → EKS

CI/CD Workflow Summary:

   Code Commit: Developer pushes code to GitHub.

   CI Pipeline: GitHub Actions (via self-hosted runner)
      1.  builds the Docker image and pushes it to ECR.
      2.  updates Kubernetes manifests in Gitea.

CD Pipeline: Argo CD detects changes in Gitea and applies them to the EKS cluster.


## Application Cluster

Set Up External Secrets Operator
   Deploy the External Secrets Operator in the Application cluster.
   Configure it to sync secrets from AWS Secrets Manager to Kubernetes secrets.

Application Deployments
   Argo CD (in Infra-EKS) continuously watches Gitea repo.
   On change, Argo CD syncs the manifests to the EKS-Apps cluster.

## Configure ALB Ingress

 Install the AWS Load Balancer Controller in the both EKS clusters.
 Annotate your Ingress resources to use ALB
 Ensure your services are exposed via the ALB with proper routing.

Set Up Route 53 DNS Records
  Create DNS records in Route 53 to point your domain/subdomain to the ALB's DNS name.


##  Security Configuration best practices


Argo CD Remote Cluster:	Use argocd-manager service account with minimum permissions (RBAC)

Kube API Access:	Restrict with security groups or IP allowlist if using public API

IRSA & Secrets:	Each cluster must have its own IAM role for External Secrets access

Gitea / GitHub Runner :	Should be on private subnets, access limited via security groups

IAM: Implement least privilege access. Use IAM roles for service accounts (IRSA) to grant Kubernetes pods access to AWS resources.

Networking: Use private subnets for EKS nodes. Only expose necessary services via public subnets.

Secrets Management: Store sensitive data in AWS Secrets Manager. Sync them to Kubernetes using External Secrets Operator.

SSL/TLS: Terminate SSL at the ALB using certificates from AWS Certificate Manager.

Monitoring & Logging (optional): Enable CloudWatch logging for EKS and ALB. Monitor logs and set up alerts for unusual activities.

## Architecture Diagram


Public Subnets:

   ALB
   NAT Gateway
   
Private Subnets:

   EKS Nodes
   Gitea
   Argo CD
   GitHub Runner
   
AWS Services:

   ECR
   Secrets Manager
   Certificate Manager
   Route 53
   CI/CD Flow:

GitHub → GitHub Runner → ECR & Gitea → Argo CD → EKS

![alt text](2025-05-31_12-07-00-1-2.gif)

