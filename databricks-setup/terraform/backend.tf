terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }

  backend "azurerm" {
    resource_group_name  = "fund-reporting-rg"
    storage_account_name = "fundreportingstracc"
    container_name       = "tfstate"
    key                  = "databricks/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}

  use_oidc = true
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.main.id
  token                       = var.databricks_azure_token
}