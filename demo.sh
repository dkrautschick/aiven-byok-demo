
set -euo pipefail

PROJECT="${PROJECT:-YOUR_AIVEN_PROJECT}"
GCP_PROJECT="${GCP_PROJECT:-aiven-sa-demo}"
REGION="${REGION:-europe-west3}"
CLOUD_NAME="${CLOUD_NAME:-google-europe-west3}"
KEYRING_NAME="${KEYRING_NAME:-YOUR_GCP_KEYRING_NAME}"
KEY_NAME="${KEY_NAME:-YOUR_GCP_KEY_NAME}"
KAFKA_PLAN="${KAFKA_PLAN:-business-4}"
PG_PLAN="${PG_PLAN:-startup-4}"
KAFKA_NAME="${KAFKA_NAME:-demo-kafka-byok}"
PG_NAME="${PG_NAME:-demo-pg-byok}"

echo "1) GCP KMS Key Ring + Key (RSA 2048)"
gcloud kms keyrings create "${KEYRING_NAME}" \
  --location "${REGION}" \
  --project "${GCP_PROJECT}" || echo "Key Ring already exists, going on..."

gcloud kms keys create "${KEY_NAME}" \
  --location "${REGION}" \
  --keyring "${KEYRING_NAME}" \
  --purpose "asymmetric-encryption" \
  --default-algorithm "rsa-decrypt-oaep-2048-sha256" \
  --project "${GCP_PROJECT}" || echo "Key already exists, going on..."

KEY_RESOURCE="projects/${GCP_PROJECT}/locations/${REGION}/keyRings/${KEYRING_NAME}/cryptoKeys/${KEY_NAME}"
echo "    Key Resource: ${KEY_RESOURCE}"

echo "2) Requesting Aivens access group for GCP KMS"
ACCESS_GROUP=$(avn project cmks accessors --project "${PROJECT}" --json | \
  python3 -c 'import json,sys; print(json.load(sys.stdin)["gcp"]["access_group"])')
echo "    Access Group: ${ACCESS_GROUP}"

echo "3) Granting Aiven access to the key (Cloud KMS CryptoKey Encrypter/Decrypter)"
gcloud kms keys add-iam-policy-binding "${KEY_NAME}" \
  --location "${REGION}" \
  --keyring "${KEYRING_NAME}" \
  --project "${GCP_PROJECT}" \
  --member "group:${ACCESS_GROUP}" \
  --role "roles/cloudkms.cryptoKeyEncrypterDecrypter"

echo "==> 4) Registering CMK in Aiven Project"
CMK_ID=$(avn project cmks create \
  --project "${PROJECT}" \
  --provider gcp \
  --resource "${KEY_RESOURCE}" \
  --default-cmk \
  --json | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['id'])")
echo "    CMK ID: ${CMK_ID}"

echo "5) create Kafka-Service with BYOK"
avn service create \
  --project "${PROJECT}" \
  --service-type kafka \
  --plan "${KAFKA_PLAN}" \
  --cloud "${CLOUD_NAME}" \
  --cmk-id "${CMK_ID}" \
  "${KAFKA_NAME}"

echo "6) create PostgreSQL-Service with BYOK"
avn service create \
  --project "${PROJECT}" \
  --service-type pg \
  --plan "${PG_PLAN}" \
  --cloud "${CLOUD_NAME}" \
  --cmk-id "${CMK_ID}" \
  "${PG_NAME}"

echo "==> 7) waiting for 'RUNNING'"
avn service wait --project "${PROJECT}" "${KAFKA_NAME}"
avn service wait --project "${PROJECT}" "${PG_NAME}"

echo "==> Bazinga!!! Checking CMS integration:"
avn project cmks get --project "${PROJECT}" --cmk-id "${CMK_ID}" -v
