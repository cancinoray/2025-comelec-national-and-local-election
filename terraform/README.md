# Terraform Infrastructure for Philippines Election Analytics

This Terraform configuration creates a complete GCP infrastructure for your Philippines election data analytics pipeline.

## 🏗️ Infrastructure Components

### Core Resources
- **BigQuery Datasets**: 3 datasets for raw data, dbt transformations, and analytics
- **Cloud Storage**: 2 buckets for data staging and dbt artifacts
- **IAM**: Service account permissions for data operations
- **APIs**: All required GCP services enabled

### Optional Features
- **Scheduling**: Cloud Scheduler for automated dbt runs
- **Monitoring**: Log-based metrics and alerting
- **Data Transfer**: Automated data loading from Cloud Storage
- **Views**: Pre-built BigQuery views for common queries

## 📋 Prerequisites

1. **GCP Project** with billing enabled
2. **Service Account** with key file in `../gcp-credentials/`
3. **Terraform** >= 1.0 installed
4. **gcloud CLI** installed and authenticated

## 🚀 Quick Start

### 1. Configure Variables
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project details
```

### 2. Deploy Infrastructure
```bash
./deploy.sh
```

### 3. Verify Deployment
```bash
terraform output
```

## ⚙️ Configuration

### Required Variables (terraform.tfvars)
```hcl
project_id             = "your-gcp-project-id"
service_account_email  = "dbt-election-analytics@your-project.iam.gserviceaccount.com"
```

### Optional Variables
```hcl
# Infrastructure settings
region                = "us-central1"
bigquery_location     = "US"
environment           = "dev"

# Advanced features
enable_scheduling     = true
enable_monitoring     = true
enable_data_transfer  = true

# Webhook for dbt automation
dbt_webhook_url       = "https://your-webhook.com/trigger-dbt"
```

## 📊 Created Resources

### BigQuery Datasets
- `philippines_election_2025` - Raw data from CSV uploads
- `philippines_election_2025_dbt` - dbt transformed data
- `philippines_election_2025_analytics` - Final analytics tables

### BigQuery Tables & Views
- **Tables**: All CSV datasets with proper schemas
- **Views**: Enhanced views with calculated fields
- **Materialized Views**: Performance-optimized summaries

### Cloud Storage Buckets
- `{project-id}-election-data-staging` - Data staging and backups
- `{project-id}-dbt-artifacts` - dbt logs and documentation

### Monitoring & Automation
- **Log Metrics**: dbt test failure tracking
- **Alerts**: Data quality issue notifications
- **Scheduler**: Daily dbt runs (if enabled)

## 🔧 Management Commands

### View Infrastructure
```bash
# All outputs
terraform output

# Specific outputs
terraform output bigquery_datasets
terraform output storage_buckets
terraform output bigquery_console_urls
```

### Update Infrastructure
```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Target specific resources
terraform apply -target=google_bigquery_dataset.raw_election_data
```

### Destroy Infrastructure
```bash
# Plan destruction
terraform plan -destroy

# Destroy all resources
terraform destroy

# Destroy specific resources
terraform destroy -target=google_cloud_scheduler_job.dbt_daily_run
```

## 📁 File Structure

```
terraform/
├── main.tf                    # Core infrastructure
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── versions.tf                # Provider versions
├── bigquery_tables.tf         # BigQuery tables and views
├── terraform.tfvars.example   # Example configuration
├── deploy.sh                  # Deployment script
├── schemas/                   # BigQuery table schemas
│   ├── election_results.json
│   ├── precincts.json
│   └── ...
└── README.md                  # This file
```

## 🔐 Security Best Practices

### Service Account Permissions
- **Principle of Least Privilege**: Only necessary roles assigned
- **Key Rotation**: Regularly rotate service account keys
- **Access Logging**: Monitor service account usage

### Data Protection
- **Bucket Versioning**: Enabled for data recovery
- **Lifecycle Policies**: Automatic data archiving
- **Access Controls**: Uniform bucket-level access

### Network Security
- **Private IPs**: Use private Google access where possible
- **VPC**: Consider VPC for enhanced security (not included)
- **Firewall Rules**: Restrict access to necessary ports

## 📈 Cost Optimization

### BigQuery
- **Slot Reservations**: Consider for predictable workloads
- **Partitioning**: Implement for large tables
- **Clustering**: Optimize query performance

### Cloud Storage
- **Storage Classes**: Automatic lifecycle management
- **Data Compression**: Use compressed formats
- **Regional Storage**: Match compute regions

### Monitoring
- **Budget Alerts**: Set up billing alerts
- **Usage Monitoring**: Track resource utilization
- **Cost Analysis**: Regular cost reviews

## 🚨 Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Check service account permissions
   gcloud projects get-iam-policy PROJECT_ID
   
   # Verify authentication
   gcloud auth list
   ```

2. **API Not Enabled**
   ```bash
   # Enable required APIs
   gcloud services enable bigquery.googleapis.com
   gcloud services enable storage.googleapis.com
   ```

3. **Quota Exceeded**
   ```bash
   # Check quotas
   gcloud compute project-info describe --project=PROJECT_ID
   
   # Request quota increase if needed
   ```

4. **Terraform State Issues**
   ```bash
   # Import existing resources
   terraform import google_bigquery_dataset.raw_election_data PROJECT_ID:DATASET_ID
   
   # Refresh state
   terraform refresh
   ```

### Debugging
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Validate configuration
terraform validate

# Format code
terraform fmt
```

## 🔄 CI/CD Integration

### GitHub Actions Example
```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
    paths: ['terraform/**']

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - name: Terraform Init
        run: terraform init
        working-directory: terraform
      - name: Terraform Plan
        run: terraform plan
        working-directory: terraform
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: terraform
```

## 📚 Additional Resources

- [Terraform GCP Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)
- [dbt on BigQuery](https://docs.getdbt.com/reference/warehouse-profiles/bigquery-profile)
- [GCP Cost Optimization](https://cloud.google.com/cost-management)

## 🤝 Contributing

To modify the infrastructure:

1. **Plan First**: Always run `terraform plan`
2. **Test Changes**: Use a development environment
3. **Document**: Update this README for significant changes
4. **Review**: Have changes reviewed before applying to production

## 📞 Support

For issues with this Terraform configuration:
1. Check the troubleshooting section above
2. Review Terraform and GCP documentation
3. Check GCP Console for resource status
4. Verify service account permissions
