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

  use_oidc        = true
  client_id       = var.arm_client_id
  tenant_id       = var.arm_tenant_id
  subscription_id = var.arm_subscription_id
}

provider "databricks" {
  host  = "https://${azurerm_databricks_workspace.main.workspace_url}"
  token = var.databricks_azure_token
}