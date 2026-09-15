variable "aiven_api_token" {
  description = "Aiven API Token"
  type        = string
  sensitive   = true
}

variable "aiven_project" {
  description = "Aiven project with BYOK ACL activated!!!"
  type        = string
}

variable "cloud_name" {
  description = "Aiven Cloud/Region, z. B. google-europe-west3"
  type        = string
  default     = "google-europe-west3"
}

variable "gcp_kms_key_resource" {
  description = <<-EOT
    projects/<project>/locations/<location>/keyRings/<keyring>/cryptoKeys/<key-name>
    asymmetric RSA-2048- or RSA-4096-Key (Aiven-Requirement for GCP KMS).
  EOT
  type = string
}

variable "kafka_plan" {
  description = "Aiven-for-Kafka Plan"
  type        = string
  default     = "business-4"
}

variable "pg_plan" {
  description = "Aiven-for-PostgreSQL Plan"
  type        = string
  default     = "business-4"
}
