variable "resource_group_name" {
  description = "Name of the Azure resource group."
  type        = string
  default     = "fund-reporting-rg"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "northeurope"
}

variable "tf_state_storage_account_name" {
  description = "Name of the storage account that will hold Terraform remote state for all other modules."
  type        = string
  default     = "fundreportingstracc"
}

variable "environment" {
  description = "Deployment environment tag (e.g. poc, dev, prod)."
  type        = string
  default     = "poc"
}
