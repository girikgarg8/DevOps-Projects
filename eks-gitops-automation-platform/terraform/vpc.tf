# Data source to get available AZs dynamically

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module - Official AWS VPC Module

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.15"

  # Basic VPC configuration
  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  # Availability zones and subnets
  # Uses first 2 available AZs dynamically from data source
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # NAT Gateway configuration for private subnet internet access
  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Kubernetes specific subnet tags
  # These tags are REQUIRED for AWS Load Balancer Controller to work.
  # The controller uses these tags to discover which subnets to use
  # when provisioning load balancers for Kubernetes services.
  # Reference: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.6/deploy/subnet_discovery/

  public_subnet_tags = {
    # Indicates this subnet can be used for public-facing (internet) load balancers
    "kubernetes.io/role/elb" = "1"
    # "shared" means multiple clusters can use the same subnets (cost-effective)
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    # Indicates this subnet can be used for internal-only load balancers
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  # apply common tags
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}