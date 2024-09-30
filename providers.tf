terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.85.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "avdstorageeasrg"
    storage_account_name = "avdeasstc02"
    container_name       = "tfstate"
    key                  = "terraform1.tfstate"
  }

}

provider "azurerm" {
  features {}
}
