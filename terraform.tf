variable "terraform_github_app_id" {
  type      = string
  sensitive = true
}

variable "terraform_github_app_installation_id" {
  type      = string
  sensitive = true
}

variable "terraform_github_app_private_key" {
  type      = string
  sensitive = true
}

terraform {

  required_version = "1.10.6"

  cloud {
    organization = "block-o"
    hostname     = "app.terraform.io"

    workspaces {
      name    = "organization-config"
      project = "default"
    }
  }

  required_providers {
    github = {
      source = "integrations/github"
      # Do not upgrade until https://github.com/integrations/terraform-provider-github/issues/2077
      version = "5.42.0"
    }
  }

}

provider "github" {
  owner = "block-o"

  app_auth {
    id              = var.terraform_github_app_id
    installation_id = var.terraform_github_app_installation_id
    pem_file        = var.terraform_github_app_private_key
  }
}
