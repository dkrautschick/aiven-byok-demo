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

resource "aiven_cmk" "gcp_cmk" {
  project      = var.aiven_project
  cmk_provider = "gcp"
  resource     = var.gcp_kms_key_resource
  default_cmk  = true
}

resource "aiven_kafka" "demo_kafka" {
  project      = var.aiven_project
  service_name = "demo-kafka-byok"
  plan         = var.kafka_plan
  cloud_name   = var.cloud_name
  cmk_id       = aiven_cmk.gcp_cmk.cmk_id

  kafka_user_config {
    kafka_version = "3.8"
  }
}

resource "aiven_pg" "demo_pg" {
  project      = var.aiven_project
  service_name = "demo-pg-byok"
  plan         = var.pg_plan
  cloud_name   = var.cloud_name
  cmk_id       = aiven_cmk.gcp_cmk.cmk_id
}

output "cmk_id" {
  description = "ID from registered CMK"
  value       = aiven_cmk.gcp_cmk.cmk_id
}

output "cmk_status" {
  value = aiven_cmk.gcp_cmk.status
}

output "kafka_service_uri" {
  value     = aiven_kafka.demo_kafka.service_uri
  sensitive = true
}

output "pg_service_uri" {
  value     = aiven_pg.demo_pg.service_uri
  sensitive = true
}
