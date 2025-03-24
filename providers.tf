terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.18.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "avdstorageeasrg"
    storage_account_name = "avdeasstc02"
    container_name       = "tfstate"
    key                  = "terraform-eas-sap-win11.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {
  enable_preflight = true
}
  
