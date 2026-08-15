##############################################################################
# Stage 2 of 2. Configures the kubernetes/helm/kubectl providers against the
# live cluster foundation created -- this is exactly why foundation and
# platform are separate root modules/states: Terraform can't configure a
# provider against a resource created earlier in the very same plan.
##############################################################################

terraform {
  required_version = ">= 1.10" # S3-native state locking (use_lockfile)

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
    # Used only by module.karpenter's EC2NodeClass/NodePool -- kubectl_manifest
    # applies raw YAML without the CRD-schema-at-plan-time requirement
    # kubernetes_manifest has, which would otherwise force a two-phase
    # `-target=helm_release.karpenter` apply on a from-scratch cluster (the
    # EC2NodeClass/NodePool CRDs come from that same Helm release). The one
    # non-HashiCorp-maintained provider in this repo -- accepted deliberately
    # for this specific, narrow problem rather than a third Terraform stage.
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "redemption-tfstate-ACCOUNT_ID" # matches backend.tf -- see its comment
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
