variable "aiven_api_token" {
  description = "Aiven API token (set via TF_VAR_aiven_api_token, never hardcode)"
  type        = string
  sensitive   = true
}

variable "aiven_project" {
  description = "Aiven project name (must have the BYOC/BYOK enterprise feature enabled)"
  type        = string
}

variable "cloud_name" {
  description = "Aiven cloud/region, e.g. azure-germany-westcentral"
  type        = string
  default     = "azure-germany-westcentral"
}

variable "azure_key_vault_key_id" {
  description = <<-EOT
    Full identifier (URI) of the Azure Key Vault key used as the
    customer-managed key (CMK).
    Format: https://<vault-name>.vault.azure.net/keys/<key-name>/<version>
    The Key Vault must use the Azure RBAC authorization model (not the
    legacy access-policy model), and Aiven's service principal (created
    from the app_id returned by `avn project cmks accessors`) must have
    the "Key Vault Crypto User" role on the key/vault.
  EOT
  type = string
}

variable "kafka_plan" {
  description = "Aiven for Kafka plan"
  type        = string
  default     = "business-4"
}

variable "pg_plan" {
  description = "Aiven for PostgreSQL plan"
  type        = string
  default     = "business-4"
}
