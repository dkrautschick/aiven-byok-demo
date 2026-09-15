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
# The AWS KMS key referenced below must already exist, and its key policy
# must already grant Aiven's IAM role principal (obtained via
# `avn project cmks accessors --project <project> --json`, field
# aws.principal) the following actions: kms:Encrypt, kms:Decrypt,
# kms:GenerateDataKey, kms:DescribeKey. See aws/demo.sh for the full
# end-to-end flow including key creation and policy setup.
# ---------------------------------------------------------------------------

resource "aiven_cmk" "aws_cmk" {
  project      = var.aiven_project
  cmk_provider = "aws"
  resource     = var.aws_kms_key_arn
  default_cmk  = true
}

resource "aiven_kafka" "demo_kafka" {
  project      = var.aiven_project
  service_name = "demo-kafka-byok"
  plan         = var.kafka_plan
  cloud_name   = var.cloud_name
  cmk_id       = aiven_cmk.aws_cmk.cmk_id

  kafka_user_config {
    kafka_version = "3.8"
  }
}

resource "aiven_pg" "demo_pg" {
  project      = var.aiven_project
  service_name = "demo-pg-byok"
  plan         = var.pg_plan
  cloud_name   = var.cloud_name
  cmk_id       = aiven_cmk.aws_cmk.cmk_id
}

output "cmk_id" {
  value = aiven_cmk.aws_cmk.cmk_id
}

output "cmk_status" {
  value = aiven_cmk.aws_cmk.status
}

output "kafka_service_uri" {
  value     = aiven_kafka.demo_kafka.service_uri
  sensitive = true
}

output "pg_service_uri" {
  value     = aiven_pg.demo_pg.service_uri
  sensitive = true
}
