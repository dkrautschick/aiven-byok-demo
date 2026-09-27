#!/usr/bin/env bash
#
# Demo: create Kafka + PostgreSQL on Aiven, encrypted with BYOK using an
# AWS KMS customer-managed key.
#
# Prerequisites:
#   - avn CLI installed and logged in
#   - aws CLI installed and configured (credentials with kms:CreateKey,
#     kms:PutKeyPolicy permissions)
#   - Aiven project with the BYOC + BYOK enterprise feature enabled
#
# Usage:
#   PROJECT=my-project AWS_REGION=eu-central-1 ./demo.sh
#
set -euo pipefail

PROJECT="${PROJECT:?Set your Aiven project in PROJECT}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
CLOUD_NAME="${CLOUD_NAME:-aws-eu-central-1}"
KAFKA_PLAN="${KAFKA_PLAN:-business-4}"
PG_PLAN="${PG_PLAN:-business-4}"
KAFKA_NAME="${KAFKA_NAME:-demo-kafka-byok}"
PG_NAME="${PG_NAME:-demo-pg-byok}"

echo "==> 1) Create an AWS KMS key"
KEY_ID=$(aws kms create-key \
  --region "${AWS_REGION}" \
  --description "Aiven BYOK demo key" \
  --key-usage ENCRYPT_DECRYPT \
  --key-spec SYMMETRIC_DEFAULT \
  --query 'KeyMetadata.KeyId' --output text)

KEY_ARN=$(aws kms describe-key \
  --region "${AWS_REGION}" \
  --key-id "${KEY_ID}" \
  --query 'KeyMetadata.Arn' --output text)
echo "    Key ARN: ${KEY_ARN}"

echo "==> 2) Look up Aiven's IAM role principal for this project"
AIVEN_PRINCIPAL=$(avn project cmks accessors --project "${PROJECT}" --json | \
  python3 -c 'import json,sys; print(json.load(sys.stdin)["aws"]["principal"])')
echo "    Aiven principal: ${AIVEN_PRINCIPAL}"

echo "==> 3) Grant Aiven's principal access via the KMS key policy"
CURRENT_POLICY=$(aws kms get-key-policy \
  --region "${AWS_REGION}" \
  --key-id "${KEY_ID}" \
  --policy-name default \
  --query 'Policy' --output text)

NEW_POLICY=$(python3 - "$CURRENT_POLICY" "$AIVEN_PRINCIPAL" <<'PY'
import json, sys
policy = json.loads(sys.argv[1])
principal = sys.argv[2]
policy["Statement"].append({
    "Sid": "AllowAivenBYOK",
    "Effect": "Allow",
    "Principal": {"AWS": principal},
    "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
    ],
    "Resource": "*"
})
print(json.dumps(policy))
PY
)

aws kms put-key-policy \
  --region "${AWS_REGION}" \
  --key-id "${KEY_ID}" \
  --policy-name default \
  --policy "${NEW_POLICY}"

echo "==> 4) Register the key as a CMK in the Aiven project"
CMK_ID=$(avn project cmks create \
  --project "${PROJECT}" \
  --provider aws \
  --resource "${KEY_ARN}" \
  --default-cmk \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])")
echo "    CMK ID: ${CMK_ID}"


echo "==> 4) Registering CMK in Aiven Project"
CMK_ID=$(avn project cmks create \
  --project "${PROJECT}" \
  --provider gcp \
  --resource "${KEY_RESOURCE}" \
  --default-cmk \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])")
echo "    CMK ID: ${CMK_ID}"




echo "==> 5) Create the Kafka service with BYOK"
avn service create \
  --project "${PROJECT}" \
  --service-type kafka \
  --plan "${KAFKA_PLAN}" \
  --cloud "${CLOUD_NAME}" \
  --cmk-id "${CMK_ID}" \
  "${KAFKA_NAME}"

echo "==> 6) Create the PostgreSQL service with BYOK"
avn service create \
  --project "${PROJECT}" \
  --service-type pg \
  --plan "${PG_PLAN}" \
  --cloud "${CLOUD_NAME}" \
  --cmk-id "${CMK_ID}" \
  "${PG_NAME}"

echo "==> 7) Wait for both services to become RUNNING"
avn service wait --project "${PROJECT}" "${KAFKA_NAME}"
avn service wait --project "${PROJECT}" "${PG_NAME}"

echo "==> Done. Verify the CMK binding:"
avn project cmks get --project "${PROJECT}" --cmk-id "${CMK_ID}" -v
