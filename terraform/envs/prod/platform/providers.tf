##############################################################################
# Stage 2 of 2. Configures the kubernetes/helm/kubectl providers against the
# live cluster foundation created -- this is exactly why foundation and
# platform are separate root modules/states: Terraform can't configure a
# provider against a resource created earlier in the very same plan.
##############################################################################

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "redemption-tfstate"
    key    = "prod/foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.foundation.outputs.cluster_name
}

provider "aws" {
  region = data.terraform_remote_state.foundation.outputs.aws_region

  default_tags {
    tags = data.terraform_remote_state.foundation.outputs.tags
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.foundation.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.foundation.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.foundation.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.foundation.outputs.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubectl" {
  host                   = data.terraform_remote_state.foundation.outputs.cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.foundation.outputs.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
