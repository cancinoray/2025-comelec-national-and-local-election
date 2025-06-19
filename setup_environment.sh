#!/bin/bash

# =============================================================================
# Philippines Election Data Analytics Pipeline - Environment Setup
# =============================================================================

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

# Check if Python 3.8+ is installed
check_python() {
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install Python 3.8 or higher."
        exit 1
    fi
    
    python_version=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
    required_version="3.8"
    
    if [ "$(printf '%s\n' "$required_version" "$python_version" | sort -V | head -n1)" != "$required_version" ]; then
        print_error "Python $python_version is installed, but Python $required_version or higher is required."
        exit 1
    fi
    
    print_success "Python $python_version is installed"
}

# Create virtual environment
create_venv() {
    print_status "Creating virtual environment..."
    
    if [ -d "venv" ]; then
        print_warning "Virtual environment already exists. Removing old environment..."
        rm -rf venv
    fi
    
    python3 -m venv venv
    print_success "Virtual environment created"
}

# Activate virtual environment and install packages
install_packages() {
    print_status "Activating virtual environment and installing packages..."
    
    # Activate virtual environment
    source venv/bin/activate
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    # Install packages from requirements.txt
    print_status "Installing packages from requirements.txt..."
    pip install -r requirements.txt
    
    print_success "All packages installed successfully"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    source venv/bin/activate
    
    # Check key packages
    python3 -c "import pandas; print(f'pandas: {pandas.__version__}')"
    python3 -c "import aiohttp; print(f'aiohttp: {aiohttp.__version__}')"
    python3 -c "import google.cloud.bigquery; print('google-cloud-bigquery: OK')"
    python3 -c "import dbt; print('dbt: OK')"
    
    print_success "Installation verified successfully"
}

# Create .env template
create_env_template() {
    print_status "Creating .env template..."
    
    if [ ! -f ".env" ]; then
        cat > .env << EOF
# =============================================================================
# Philippines Election Data Analytics Pipeline - Environment Variables
# =============================================================================

# Google Cloud Platform
GCP_PROJECT_ID=your-gcp-project-id
GOOGLE_APPLICATION_CREDENTIALS=./gcp-credentials/service-account-key.json

# Data Collection Settings
MAX_CONCURRENT_REQUESTS=10
DATA_OUTPUT_DIR=./election_data
LOGS_DIR=./logs

# BigQuery Settings
BIGQUERY_DATASET_RAW=philippines_election_2025
BIGQUERY_DATASET_DBT=philippines_election_2025_dbt
BIGQUERY_DATASET_ANALYTICS=philippines_election_2025_analytics
BIGQUERY_LOCATION=US

# dbt Settings
DBT_PROFILES_DIR=./dbt_election_analytics
DBT_TARGET=dev

# Optional: Webhook for automation
# DBT_WEBHOOK_URL=https://your-webhook-url.com/trigger-dbt

# Optional: Notification settings
# NOTIFICATION_EMAIL=your-email@example.com
EOF
        print_success "Created .env template - please update with your values"
    else
        print_warning ".env file already exists - skipping template creation"
    fi
}

# Create directories
create_directories() {
    print_status "Creating project directories..."
    
    mkdir -p logs
    mkdir -p election_data
    mkdir -p election_data_overseas
    mkdir -p csv_datasets
    mkdir -p analysis_output
    mkdir -p gcp-credentials
    
    print_success "Project directories created"
}

# Main setup function
main() {
    echo "🗳️  Philippines Election Data Analytics Pipeline"
    echo "=================================================="
    echo
    
    check_python
    create_venv
    install_packages
    verify_installation
    create_env_template
    create_directories
    
    echo
    print_success "Environment setup completed successfully!"
    echo
    print_status "Next steps:"
    echo "1. Activate the virtual environment: source venv/bin/activate"
    echo "2. Update .env file with your GCP project details"
    echo "3. Place your GCP service account key in gcp-credentials/"
    echo "4. Configure Terraform: cd terraform && cp terraform.tfvars.example terraform.tfvars"
    echo "5. Deploy infrastructure: cd terraform && ./deploy.sh"
    echo "6. Run data collection: python main.py"
    echo "7. Process data: python convert_to_csv.py"
    echo "8. Upload to BigQuery: python gcp_upload_pipeline.py"
    echo "9. Run dbt transformations: cd dbt_election_analytics && dbt run"
    echo
    print_status "For detailed instructions, see README.md"
    echo
    print_warning "Remember to:"
    echo "- Keep your GCP credentials secure"
    echo "- Review and update .env variables"
    echo "- Test with a small dataset first"
}

# Run main function
main
