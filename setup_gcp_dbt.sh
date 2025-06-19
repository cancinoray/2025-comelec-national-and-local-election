#!/bin/bash

# Setup script for GCP BigQuery + dbt pipeline
# Make sure to set your GCP project ID and configure authentication

set -e

echo "🚀 Setting up GCP BigQuery + dbt pipeline for Philippines Election Data"

# Check if required environment variables are set
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "❌ Please set GCP_PROJECT_ID environment variable"
    echo "   export GCP_PROJECT_ID=your-project-id"
    exit 1
fi

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements_gcp.txt

# Authenticate with GCP (if not already done)
echo "🔐 Checking GCP authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "Please authenticate with GCP:"
    echo "gcloud auth login"
    echo "gcloud auth application-default login"
    exit 1
fi

# Set the project
gcloud config set project $GCP_PROJECT_ID

# Enable required APIs
echo "🔧 Enabling required GCP APIs..."
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com

# Create service account for dbt (if it doesn't exist)
SERVICE_ACCOUNT_NAME="dbt-election-analytics"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT_EMAIL >/dev/null 2>&1; then
    echo "👤 Creating service account for dbt..."
    gcloud iam service-accounts create $SERVICE_ACCOUNT_NAME \
        --display-name="dbt Election Analytics Service Account"
    
    # Grant necessary permissions
    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="roles/bigquery.admin"
    
    gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
        --role="roles/storage.admin"
fi

# Create and download service account key
KEY_FILE="./gcp-credentials/service-account-key.json"
mkdir -p gcp-credentials

if [ ! -f "$KEY_FILE" ]; then
    echo "🔑 Creating service account key..."
    gcloud iam service-accounts keys create $KEY_FILE \
        --iam-account=$SERVICE_ACCOUNT_EMAIL
fi

# Update dbt profiles with actual project ID
echo "⚙️  Updating dbt profiles with project ID..."
sed -i "s/your-gcp-project-id/$GCP_PROJECT_ID/g" dbt_election_analytics/profiles.yml

# Update upload script with project ID
sed -i "s/your-gcp-project-id/$GCP_PROJECT_ID/g" gcp_upload_pipeline.py

# Install dbt packages
echo "📚 Installing dbt packages..."
cd dbt_election_analytics
dbt deps
cd ..

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Run the upload pipeline: python gcp_upload_pipeline.py"
echo "2. Test dbt connection: cd dbt_election_analytics && dbt debug"
echo "3. Run dbt models: dbt run"
echo "4. Generate documentation: dbt docs generate && dbt docs serve"
