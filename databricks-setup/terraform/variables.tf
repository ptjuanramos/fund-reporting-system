variable "project-name" {
  description = "Name of the project for tagging purposes."
  type        = string
  default     = "fund-reporting"
}

variable "resource_group_name" {
  description = "Resource group that was created by the cold-start module."
  type        = string
  default     = "fund-reporting-rg"
}

variable "workspace_name" {
  description = "Name of the Databricks workspace."
  type        = string
  default     = "fund-reporting-dbw"
}

variable "environment" {
  description = "Deployment environment tag (e.g. poc, dev, prod)."
  type        = string
  default     = "dev"
}

variable "databricks_azure_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "admin_user_email" {
  description = "Email of the human user to add as workspace admin."
  type        = string
}

variable "arm_client_id" {
  type      = string
  sensitive = true
}

variable "arm_tenant_id" {
  type      = string
  sensitive = true
}

variable "arm_subscription_id" {
  type      = string
  sensitive = true
}
