# aiven-byok-demo

Working, cloud-by-cloud examples of setting up **Bring Your Own Key (BYOK)** for Aiven services (Kafka + PostgreSQL) using **AWS KMS**, **Azure Key Vault**, and **Google Cloud KMS**. Each cloud has both a shell-script (`avn` CLI) walkthrough and an equivalent Terraform configuration.

Repo: https://github.com/dkrautschick/aiven-byok-demo

## What this repo shows

BYOK lets you keep the encryption key for your Aiven service in a key management system that *you* control, instead of a key Aiven generates and manages for you. Aiven is only ever granted a narrow, revocable permission to use that key for encrypt/decrypt operations — never to export, rotate, or delete it. This repo demonstrates the full loop for each of the three major clouds:

1. Create a customer-managed key in your own cloud KMS.
2. Grant Aiven's project a scoped permission to use that key.
3. Register the key as a CMK (customer-managed key) in your Aiven project.
4. Create a Kafka and a PostgreSQL service on Aiven, each encrypted with that CMK.

## Repository layout

```
aiven-byok-demo/
├── README.md              # Background on BYOK (this repo's landing page)
├── aws/
│   ├── demo.sh            # avn CLI + aws CLI walkthrough
│   ├── main.tf             # Terraform equivalent
│   └── variables.tf
├── azure/
│   ├── demo.sh             # avn CLI + az CLI walkthrough
│   ├── main.tf
│   └── variables.tf
└── gcp/
    ├── demo.sh             # avn CLI + gcloud CLI walkthrough
    ├── main.tf
    └── variables.tf
```

Pick the folder for your cloud provider; each one is self-contained.

## Prerequisites (all clouds)

- [`avn` CLI](https://github.com/aiven/aiven-client) installed and logged in (`avn user login`).
- An Aiven project with the **BYOC + BYOK enterprise feature** enabled. This is not on by default — contact Aiven support/sales first, or the CMK creation step will fail.
- Your cloud provider's CLI installed and authenticated:
  - AWS: `aws` CLI, credentials with `kms:CreateKey` and `kms:PutKeyPolicy` permissions.
  - Azure: `az` CLI, logged in as a user with **Owner** or **Contributor + User Access Administrator** on the target subscription/resource group (needed to create the Key Vault and assign roles).
  - GCP: `gcloud` CLI, authenticated against a project where you can create KMS key rings/keys and edit their IAM policy (effectively `roles/cloudkms.admin` or equivalent).
- [Terraform](https://developer.hashicorp.com/terraform) ≥ 1.x if you want to use the `.tf` files instead of the shell scripts.

**Heads-up:** the cloud-side KMS/Key Vault permissions above are usually the slow part. If you're not the admin of your cloud account, budget time to get the right role assigned before you start — the Aiven-side steps take minutes once the key is ready.

## Option A — Run it with the `avn` CLI (`demo.sh`)

Each `demo.sh` is a self-contained script. Set the required environment variables and run it.

### AWS

```bash
cd aws
PROJECT=my-aiven-project AWS_REGION=eu-central-1 ./demo.sh
```

What it does:
1. Creates a symmetric AWS KMS key.
2. Looks up Aiven's IAM principal for your project via `avn project cmks accessors`.
3. Appends an `AllowAivenBYOK` statement to the key's policy, granting `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey`, `kms:DescribeKey` only.
4. Registers the key as the project's default CMK.
5. Creates a Kafka and a PostgreSQL service, both bound to that CMK.
6. Waits for both services to reach `RUNNING` and prints the CMK status.

Optional overrides: `CLOUD_NAME`, `KAFKA_PLAN`, `PG_PLAN`, `KAFKA_NAME`, `PG_NAME`.

### Azure

```bash
cd azure
PROJECT=my-aiven-project RESOURCE_GROUP=aiven-byok-demo LOCATION=germanywestcentral \
  VAULT_NAME=aiven-byok-demo-kv ./demo.sh
```

What it does:
1. Registers the `Microsoft.KeyVault` resource provider (safe to skip if already done).
2. Creates a resource group and a Key Vault using the **RBAC authorization model** (the legacy access-policy model will not work here).
3. Creates an RSA-2048 key inside the vault.
4. Looks up Aiven's Azure AD `app_id` via `avn project cmks accessors`.
5. Registers Aiven's application as a service principal in your own tenant (`az ad sp create`).
6. Assigns the **Key Vault Crypto User** role on the vault to that service principal.
7. Registers the key as the project's default CMK.
8. Creates a Kafka and a PostgreSQL service bound to that CMK, and waits for both to be `RUNNING`.

Optional overrides: `KEY_NAME`, `CLOUD_NAME`, `KAFKA_PLAN`, `PG_PLAN`, `KAFKA_NAME`, `PG_NAME`.

### GCP

```bash
cd gcp
PROJECT=my-aiven-project GCP_PROJECT=my-gcp-project REGION=europe-west3 \
  KEYRING_NAME=aiven-byok-keyring KEY_NAME=aiven-byok-key ./demo.sh
```

What it does:
1. Creates a KMS key ring and an **asymmetric** key (`rsa-decrypt-oaep-2048-sha256`) — GCP is the one cloud here where Aiven specifically requires an asymmetric key.
2. Looks up Aiven's access group for your project via `avn project cmks accessors`.
3. Grants that group the `roles/cloudkms.cryptoKeyEncrypterDecrypter` role on the key.
4. Registers the key as the project's default CMK.
5. Creates a Kafka and a PostgreSQL service bound to that CMK, and waits for both to be `RUNNING`.

Optional overrides: `CLOUD_NAME`, `KAFKA_PLAN`, `PG_PLAN`, `KAFKA_NAME`, `PG_NAME`.

## Option B — Run it with Terraform

Each cloud folder also has a matching `main.tf` / `variables.tf` pair. They assume the KMS key / Key Vault key **already exists and already has Aiven's access granted** — Terraform only handles the Aiven-side registration and service creation, not the cloud-side key/permission setup (that part still has to happen via the cloud's CLI/console first, exactly as in `demo.sh` steps 1–3).

```bash
cd aws   # or azure / gcp
terraform init

export TF_VAR_aiven_api_token="<your Aiven API token>"
terraform apply \
  -var="aiven_project=my-aiven-project" \
  -var="aws_kms_key_arn=arn:aws:kms:eu-central-1:123456789012:key/<key-id>"
  # (swap the last var for azure_key_vault_key_id / gcp_kms_key_resource in the other folders)
```

Never hardcode `aiven_api_token` in a `.tfvars` file that gets committed — always pass it via `TF_VAR_aiven_api_token` or a secret manager.

Each `main.tf` creates:
- `aiven_cmk` — registers your cloud key as the project's customer-managed key.
- `aiven_kafka` — a Kafka service bound to that CMK.
- `aiven_pg` — a PostgreSQL service bound to that CMK.

And outputs the CMK ID/status plus the (sensitive) service connection URIs.

## Verifying it worked

Regardless of which path you used:

```bash
avn project cmks get --project my-aiven-project --cmk-id <CMK_ID> -v
```

This should show the CMK's provider, resource identifier, and status. From here on, backups and data at rest for both services are encrypted exclusively with your own key.

## Cleaning up

The scripts don't tear anything down automatically. To avoid leaving demo services (and demo keys) running:

```bash
avn service terminate --project my-aiven-project demo-kafka-byok
avn service terminate --project my-aiven-project demo-pg-byok
avn project cmks delete --project my-aiven-project --cmk-id <CMK_ID>
```

...then remove the KMS key / Key Vault / key ring on the cloud side through its own console or CLI, if you created it purely for this demo.

## Related reading

A longer write-up on why BYOK matters and what's happening under the hood is in [`byok-sovereignty-blog-post.md`](./byok-sovereignty-blog-post.md) in this same repo.
