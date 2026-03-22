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
