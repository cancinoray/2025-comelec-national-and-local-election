#!/bin/bash

# Terraform deployment script for Election Analytics Infrastructure
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found!"
    print_status "Please copy terraform.tfvars.example to terraform.tfvars and update with your values:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo "  # Edit terraform.tfvars with your project details"
    exit 1
fi

# Check if service account key exists
CREDENTIALS_FILE=$(grep -E "^credentials_file" terraform.tfvars | cut -d'"' -f2 || echo "../gcp-credentials/service-account-key.json")
if [ ! -f "$CREDENTIALS_FILE" ]; then
    print_error "Service account key not found at: $CREDENTIALS_FILE"
    print_status "Please ensure your service account key is in the correct location"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install Terraform first."
    echo "Visit: https://learn.hashicorp.com/tutorials/terraform/install-cli"
    exit 1
fi

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed. Please install it first."
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check gcloud authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    print_error "gcloud is not authenticated. Please run:"
    echo "  gcloud auth login"
    echo "  gcloud auth application-default login"
    exit 1
fi

# Extract project ID from terraform.tfvars
PROJECT_ID=$(grep -E "^project_id" terraform.tfvars | cut -d'"' -f2)
if [ -z "$PROJECT_ID" ]; then
    print_error "project_id not found in terraform.tfvars"
    exit 1
fi

print_status "Deploying infrastructure for project: $PROJECT_ID"

# Set the gcloud project
gcloud config set project "$PROJECT_ID"

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Validate Terraform configuration
print_status "Validating Terraform configuration..."
terraform validate

# Plan the deployment
print_status "Planning Terraform deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo
print_warning "Review the plan above. Do you want to proceed with the deployment? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    print_status "Deployment cancelled."
    rm -f tfplan
    exit 0
fi

# Apply the configuration
print_status "Applying Terraform configuration..."
terraform apply tfplan

# Clean up plan file
rm -f tfplan

print_success "Infrastructure deployment completed!"
echo
print_status "Next steps:"
echo "1. Upload your data: cd .. && python gcp_upload_pipeline.py"
echo "2. Run dbt transformations: cd ../dbt_election_analytics && dbt run"
echo "3. View your BigQuery datasets in the console"
echo
print_status "Useful commands:"
echo "  terraform output                    # View all outputs"
echo "  terraform output bigquery_datasets # View BigQuery dataset info"
echo "  terraform destroy                   # Clean up resources (when done)"
