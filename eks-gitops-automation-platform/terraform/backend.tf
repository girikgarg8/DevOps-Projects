terraform {
  backend "s3" {
    bucket         = "eks-gitops-tfstate-ggarg1"
    key            = "eks-cluster/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "eks-gitops-terraform-locks"
    encrypt        = true
  }
}

