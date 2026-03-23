data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_databricks_workspace" "main" {
  name                = var.workspace_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  sku                 = "standard"

  tags = local.common_tags
}

resource "databricks_cluster_policy" "cost_control" {
  name = "${local.common_tags.project}-cost-control"

  definition = jsonencode({
    "autotermination_minutes" = {
      type  = "fixed"
      value = 30
    }
    "node_type_id" = {
      type  = "allowlist"
      values = ["Standard_DS3_v2"]
    }
    "num_workers" = {
      type       = "range"
      minValue   = 0 
      maxValue   = 4
    }
    "spark_version" = {
      type = "unlimited"
      defaultValue = "lts"
    }
  })
}

data "databricks_group" "admins" {
  display_name = "admins"
}

resource "databricks_user" "admin" {
  user_name = var.admin_user_email
}

resource "databricks_group_member" "admin" {
  group_id  = data.databricks_group.admins.id
  member_id = databricks_user.admin.id
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_storage_account" "bronze" {
  name                     = "fundreporting${random_string.suffix.result}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS" 

  is_hns_enabled           = true

  min_tls_version          = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = {
    project     = var.project-name
    environment = var.environment
    managed_by  = "terraform"
  }
}


resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_name  = azurerm_storage_account.bronze.name
  container_access_type = "private"
}

locals {
  common_tags = {
    project     = var.project-name
    environment = var.environment
    managed_by  = "terraform"
  }
}
