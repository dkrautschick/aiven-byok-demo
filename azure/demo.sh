#!/usr/bin/env bash
#
# Demo: create Kafka + PostgreSQL on Aiven, encrypted with BYOK using an
# Azure Key Vault customer-managed key.
#
# Prerequisites:
#   - avn CLI installed and logged in
#   - az CLI installed and logged in (Owner/Contributor + User Access
#     Administrator on the target subscription/resource group)
#   - Aiven project with the BYOC + BYOK enterprise feature enabled
#
# Usage:
#   PROJECT=my-project RESOURCE_GROUP=aiven-byok-demo LOCATION=germanywestcentral \
#     VAULT_NAME=aiven-byok-demo-kv ./demo.sh
#
set -euo pipefail

PROJECT="${PROJECT:?Set your Aiven project in PROJECT}"
RESOURCE_GROUP="${RESOURCE_GROUP:-aiven-byok-demo}"
LOCATION="${LOCATION:-germanywestcentral}"
VAULT_NAME="${VAULT_NAME:-aiven-byok-demo-kv}"
KEY_NAME="${KEY_NAME:-aiven-byok-demo-key}"
CLOUD_NAME="${CLOUD_NAME:-azure-germany-westcentral}"
KAFKA_PLAN="${KAFKA_PLAN:-business-4}"
PG_PLAN="${PG_PLAN:-business-4}"
KAFKA_NAME="${KAFKA_NAME:-demo-kafka-byok}"
PG_NAME="${PG_NAME:-demo-pg-byok}"

echo "==> 0) Register the Key Vault resource provider (skip if already done)"
az provider register --namespace Microsoft.KeyVault --wait || true

echo "==> 1) Create resource group + Key Vault (RBAC authorization model)"
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" >/dev/null

az keyvault create \
  --name "${VAULT_NAME}" \
  --resource-group "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --enable-rbac-authorization true

echo "==> 2) Create the key"
KEY_ID=$(az keyvault key create \
  --vault-name "${VAULT_NAME}" \
  --name "${KEY_NAME}" \
  --kty RSA \
  --size 2048 \
  --query 'key.kid' --output tsv)
echo "    Key ID: ${KEY_ID}"

echo "==> 3) Look up Aiven's Azure AD app_id for this project"
AIVEN_APP_ID=$(avn project cmks accessors --project "${PROJECT}" --json | \
  python3 -c 'import json,sys; print(json.load(sys.stdin)["azure"]["app_id"])')
echo "    Aiven app_id: ${AIVEN_APP_ID}"

echo "==> 4) Register Aiven's multi-tenant application as a service principal in your tenant"
az ad sp create --id "${AIVEN_APP_ID}" || echo "Service principal already exists, continuing."

echo "==> 5) Assign the 'Key Vault Crypto User' role on the vault to Aiven's service principal"
VAULT_ID=$(az keyvault show --name "${VAULT_NAME}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv)
az role assignment create \
  --assignee "${AIVEN_APP_ID}" \
  --role "Key Vault Crypto User" \
  --scope "${VAULT_ID}"

echo "==> 6) Register the key as a CMK in the Aiven project"
CMK_ID=$(avn project cmks create \
  --project "${PROJECT}" \
  --provider azure \
  --resource "${KEY_ID}" \
  --default-cmk \
  --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
echo "    CMK ID: ${CMK_ID}"

echo "==> 7) Create the Kafka service with BYOK"
avn service create \
  --project "${PROJECT}" \
  --service-type kafka \
  --plan "${KAFKA_PLAN}" \
  --cloud "${CLOUD_NAME}" \
  --cmk-id "${CMK_ID}" \
  "${KAFKA_NAME}"

echo "==> 8) Create the PostgreSQL service with BYOK"
avn service create \
  --project "${PROJECT}" \
  --service-type pg \
  --plan "${PG_PLAN}" \
  --cloud "${CLOUD_NAME}" \
  --cmk-id "${CMK_ID}" \
  "${PG_NAME}"

echo "==> 9) Wait for both services to become RUNNING"
avn service wait --project "${PROJECT}" "${KAFKA_NAME}"
avn service wait --project "${PROJECT}" "${PG_NAME}"

echo "==> Done. Verify the CMK binding:"
avn project cmks get --project "${PROJECT}" --cmk-id "${CMK_ID}" -v
