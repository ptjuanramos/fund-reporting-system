output "resource_group_name" {
  description = "Name of the provisioned resource group."
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ARM resource ID of the resource group."
  value       = azurerm_resource_group.main.id
}

output "tf_state_storage_account_name" {
  description = "Storage account that holds Terraform remote state."
  value       = azurerm_storage_account.tfstate.name
}

output "tf_state_container_name" {
  description = "Blob container inside the storage account for state files."
  value       = azurerm_storage_container.tfstate.name
}
