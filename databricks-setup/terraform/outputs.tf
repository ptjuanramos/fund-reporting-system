output "workspace_url" {
  description = "HTTPS URL of the Databricks workspace."
  value       = "https://${azurerm_databricks_workspace.main.workspace_url}"
}

output "workspace_id" {
  description = "Numeric Databricks workspace ID."
  value       = azurerm_databricks_workspace.main.workspace_id
}

output "workspace_resource_id" {
  description = "ARM resource ID of the Databricks workspace."
  value       = azurerm_databricks_workspace.main.id
}

output "cluster_policy_id" {
  description = "ID of the cost-control cluster policy."
  value       = databricks_cluster_policy.cost_control.id
}

output "storage_account_name" {
  description = "Paste into STORAGE_ACCOUNT in the notebook"
  value       = azurerm_storage_account.bronze.name
}

output "container_name" {
  description = "Paste into CONTAINER in the notebook"
  value       = azurerm_storage_container.bronze.name
}

output "abfss_path" {
  description = "Full ADLS Gen2 path"
  value       = "abfss://${azurerm_storage_container.bronze.name}@${azurerm_storage_account.bronze.name}.dfs.core.windows.net/fund_reporting_bronze"
}