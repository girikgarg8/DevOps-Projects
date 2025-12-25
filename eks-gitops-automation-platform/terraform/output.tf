# VPC Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

# EKS Outputs

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

# Configuration commands

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "get_nodes_command" {
  description = "Command to get nodes"
  value       = "kubectl get nodes -o wide"
}

output "get_pods_command" {
  description = "Command to get all pods"
  value       = "kubectl get pods -A"
}

# Resource summary

output "resource_summary" {
  description = "Summary of created resources"
  value       = <<-EOT
    ========================================
    EKS GitOps Automation Platform
    ========================================
    
    Region:              ${var.region}
    Environment:         ${var.environment}
    
    VPC:
      CIDR:              ${var.vpc_cidr}
      Public Subnets:    2
      Private Subnets:   2
      NAT Gateways:      ${var.single_nat_gateway ? 1 : 2}
    
    EKS Cluster:
      Name:              ${var.cluster_name}
      Version:           ${var.kubernetes_version}
      Node Type:         ${var.node_instance_types[0]}
      Node Count:        ${var.desired_nodes} (min: ${var.min_nodes}, max: ${var.max_nodes})
      Capacity Type:     ${var.node_capacity_type}
      Disk Size:         ${var.node_disk_size} GB
    
    ========================================
  EOT
}