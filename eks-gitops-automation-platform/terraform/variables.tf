# AWS Configuration

variable "access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS region"
  type        = string
}

# Project configuration

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
}

# VPC configuration

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway (true) or one per AZ(false)"
  type        = bool
}

# EKS Configuration

variable "cluster_name" {
  description = "EKS Cluster Name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

# Node Group configuration
variable "node_instance_types" {
  description = "Instance types for worker nodes"
  type        = list(string)
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
}

variable "min_nodes" {
  description = "Minimum number of nodes"
  type        = number
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
}

variable "desired_nodes" {
  description = "Desired number of nodes"
  type        = number
}

variable "node_capacity_type" {
  description = "Capacity Type: ON_DEMAND or SPOT"
  type        = string
}

# Tags
variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}
