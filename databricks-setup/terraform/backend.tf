terraform {
  backend "azurerm" {
    resource_group_name  = "fund-reporting-rg"
    storage_account_name = "fundreportingstracc"
    container_name       = "tfstate"
    key                  = "databricks/terraform.tfstate"
  }
}
