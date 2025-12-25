# Data source to get current AWS caller identity
data "aws_caller_identity" "current" {}

# EKS Module - Official AWS EKS Module

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # Cluster basic configuration
  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  # VPC configuration - which is created in vpc.tf
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cluster endpoint access configuration
  cluster_endpoint_public_access  = true # Allows access to the EKS API Server through Internet
  cluster_endpoint_private_access = true # Allows access to the EKS API Server within cluster

  # Access entries - Grant IAM principals access to the cluster
  # This allows the current AWS user/role to access the Kubernetes API via kubectl
  # The principal_arn is dynamically fetched from the current AWS session
  access_entries = {
    # Terraform user - for kubectl access from local machine
    current_user = {
      principal_arn = data.aws_caller_identity.current.arn
      
      # Grant cluster admin permissions
      # AmazonEKSClusterAdminPolicy provides full admin access to the cluster
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster" # Cluster-wide access (alternative: "namespace" for specific namespace access)
          }
        }
      }
    }
    
    # Root user - for AWS Console access
    # Dynamically constructs root ARN using current account ID
    root_user = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # EKS Managed Node Groups

  eks_managed_node_groups = {
    general = {
      name = "${var.project_name}-node-group"

      #Instance configuration
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      # Scaling configuration
      min_size     = var.min_nodes
      max_size     = var.max_nodes
      desired_size = var.desired_nodes

      # Disk configuration
      disk_size = var.node_disk_size

      # Labels for pod scheduling
      labels = {
        role        = "general"
        environment = var.environment
      }

      # Configuration in case of node updates
      update_config = {
        max_unavailable_percentage = 50
      }

      # Tags for node instances
      tags = merge(var.common_tags, {
        Name = "${var.project_name}-node"
      })
    }
  }

  # Cluster addons - essential components for EKS
  cluster_addons = {
    # CoreDNS for DNS resolution within cluster
    coredns = {
      most_recent = true
    }
    # kube-proxy for network rules on nodes
    kube-proxy = {
      most_recent = true
    }
    # VPC CNI for pod networking
    vpc-cni = {
      most_recent = true
    }
  }

  # Apply common tags to cluster
  tags = var.common_tags

}