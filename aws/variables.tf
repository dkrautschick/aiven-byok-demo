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
  description = "Aiven cloud/region, e.g. aws-eu-central-1"
  type        = string
  default     = "aws-eu-central-1"
}

variable "aws_kms_key_arn" {
  description = <<-EOT
    ARN of the AWS KMS key used as the customer-managed key (CMK).
    Format: arn:aws:kms:<region>:<account-id>:key/<key-id>
    The key policy must already grant Aiven's IAM role principal
    (from `avn project cmks accessors`) kms:Encrypt / kms:Decrypt /
    kms:GenerateDataKey / kms:DescribeKey.
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
