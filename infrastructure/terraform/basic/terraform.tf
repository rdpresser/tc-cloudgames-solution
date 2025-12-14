terraform {
  required_version = ">= 1.14"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.56"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  cloud {
    organization = "rdpresser_tccloudgames_fiap"
    workspaces {
      name = "tcc-games-test-basic"
    }
  }
}