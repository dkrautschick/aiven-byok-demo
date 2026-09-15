terraform {
  required_providers {
    aiven = {
      source  = "aiven/aiven"
      version = ">= 4.0.0"
    }
  }
}

provider "aiven" {
  api_token = var.aiven_api_token
}

# ---------------------------------------------------------------------------
# NOTE: BYOK is a BYOC enterprise feature and only available for newly
# created BYOC services. Contact Aiven support/sales to have it enabled on
# your project before running this.
#
# The Azure Key Vault key referenced below must already exist in a Key
# Vault using the Azure RBAC authorization model, and Aiven's service
# principal (registered in your Azure AD tenant from the app_id returned
# by `avn project cmks accessors --project <project> --json`, field
# azure.app_id) must already have the "Key Vault Crypto User" role
# assigned on it. See azure/demo.sh for the full end-to-end flow.
# ---------------------------------------------------------------------------

resource "aiven_cmk" "azure_cmk" {
  project      = var.aiven_project
  cmk_provider = "azure"
  resource     = var.azure_key_vault_key_id
  default_cmk  = true
}

resource "aiven_kafka" "demo_kafka" {
  project      = var.aiven_project
  service_name = "demo-kafka-byok"
  plan         = var.kafka_plan
  cloud_name   = var.cloud_name
  cmk_id       = aiven_cmk.azure_cmk.cmk_id

  kafka_user_config {
    kafka_version = "3.8"
  }
}

resource "aiven_pg" "demo_pg" {
  project      = var.aiven_project
  service_name = "demo-pg-byok"
  plan         = var.pg_plan
  cloud_name   = var.cloud_name
  cmk_id       = aiven_cmk.azure_cmk.cmk_id
}

output "cmk_id" {
  value = aiven_cmk.azure_cmk.cmk_id
}

output "cmk_status" {
  value = aiven_cmk.azure_cmk.status
}

output "kafka_service_uri" {
  value     = aiven_kafka.demo_kafka.service_uri
  sensitive = true
}

output "pg_service_uri" {
  value     = aiven_pg.demo_pg.service_uri
  sensitive = true
}
