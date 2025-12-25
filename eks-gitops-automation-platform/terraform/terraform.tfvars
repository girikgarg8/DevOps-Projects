# AWS configuration

region = "ap-south-1"

# Project configuration

project_name = "eks-gitops"
environment  = "dev"

# VPC Configuration

vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
single_nat_gateway   = true

# EKS Configuration
cluster_name       = "eks-gitops-cluster"
kubernetes_version = "1.31"

node_instance_types = ["m7i-flex.large"]
node_disk_size      = 30
min_nodes           = 1
max_nodes           = 2
desired_nodes       = 1
node_capacity_type  = "ON_DEMAND"


common_tags = {
  "Project"   = "eks-gitops-automation"
  "ManagedBy" = "Terraform"
  "Owner"     = "ggarg1"
}