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

locals {
  common_tags = {
    project     = var.project-name
    environment = var.environment
    managed_by  = "terraform"
  }
}
