# 2025 COMELEC National and Local Election Data Analytics Platform

A comprehensive data engineering platform for collecting, processing, and analyzing election data from the 2025 Philippines Commission on Elections (COMELEC) national and local elections.

## 🏗️ Platform Overview

This repository provides a complete data analytics pipeline that includes:

1. **Data Collection**: Asynchronous web scraping from COMELEC website
2. **Data Processing**: CSV conversion and data validation
3. **Cloud Infrastructure**: GCP BigQuery and Cloud Storage setup via Terraform
4. **Data Transformation**: dbt models for analytics-ready datasets
5. **Analytics**: Pre-built models for election insights and visualization

## 🚀 Quick Start

### Automated Environment Setup (Recommended)
```bash
# Clone the repository
git clone <repository-url>
cd 2025-comelec-national-and-local-election

# Run automated environment setup
./setup_environment.sh

# Activate virtual environment
source venv/bin/activate

# Update environment variables
nano .env  # Update with your GCP project details
```

### Option 1: Full Pipeline Deployment
```bash
# 1. Set up infrastructure
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project details
./deploy.sh

# 2. Upload data to BigQuery
cd .. && python gcp_upload_pipeline.py

# 3. Run dbt transformations
cd dbt_election_analytics && dbt run && dbt test
```

### Option 2: Local Analysis Only
```bash
# Run data collection
python main.py

# Convert to CSV for analysis
python convert_to_csv.py
```

## 📊 Data Engineering Architecture

```
Raw Data Collection → CSV Processing → BigQuery → dbt Transformations → Analytics
       ↓                    ↓             ↓              ↓                ↓
   JSON Files         Structured CSVs   Raw Tables   Staging Models    Mart Tables
   (92K+ files)       (10 datasets)    (BigQuery)   (Data Quality)   (Analytics)
```

## 🛠️ Environment Setup

### Prerequisites
- Python 3.8 or higher
- Google Cloud Platform account
- Terraform >= 1.0 (for infrastructure deployment)

### Automated Setup
The project includes an automated setup script that handles everything:

```bash
./setup_environment.sh
```

This script will:
- ✅ Check Python version compatibility
- ✅ Create and configure virtual environment
- ✅ Install all required dependencies
- ✅ Create project directories
- ✅ Generate .env template with all variables
- ✅ Verify installation of key packages

### Manual Setup
If you prefer manual setup:

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# For development work
pip install -r requirements-dev.txt
```

### Dependencies Overview
The `requirements.txt` includes comprehensive packages for:

- **Core Data Processing**: pandas, numpy
- **Async Web Scraping**: aiohttp, asyncio-throttle
- **Data Visualization**: matplotlib, plotly, seaborn, geopandas, folium
- **Google Cloud Platform**: BigQuery, Storage, Auth libraries
- **dbt Integration**: dbt-core, dbt-bigquery
- **Data Quality**: great-expectations, pytest
- **Development Tools**: black, flake8, isort, jupyter
- **Advanced Analytics**: scikit-learn, statsmodels

## 📁 Project Structure

```
├── 📁 dbt_election_analytics/    # dbt transformation project
│   ├── models/                   # dbt models (staging, intermediate, marts)
│   ├── tests/                    # Data quality tests
│   └── dbt_project.yml          # dbt configuration
├── 📁 terraform/                 # Infrastructure as Code
│   ├── bigquery_tables.tf        # BigQuery resources
│   ├── cloud_storage.tf          # Storage buckets
│   ├── iam.tf                    # IAM permissions
│   ├── monitoring.tf             # Optional monitoring
│   ├── scheduling.tf             # Optional automation
│   ├── schemas/                  # BigQuery table schemas
│   └── deploy.sh                 # Automated deployment script
├── 📁 election_data/             # Raw JSON data (gitignored)
├── 📁 csv_datasets/              # Processed CSV datasets (gitignored)
├── 📁 analysis_output/           # Analysis results and visualizations
├── 📁 logs/                      # Application logs
├── 📁 gcp-credentials/           # GCP service account keys (gitignored)
├── main.py                       # Primary data collection script
├── scrape_overseas.py            # Overseas data collection
├── convert_to_csv.py             # JSON to CSV conversion
├── gcp_upload_pipeline.py        # BigQuery data upload
├── setup_environment.sh          # Automated environment setup
├── requirements.txt              # Production dependencies
├── requirements-dev.txt          # Development dependencies
├── .env                          # Environment variables (created by setup)
└── README.md                     # This file

## 📈 Key Datasets

| Dataset | Size | Records | Description |
|---------|------|---------|-------------|
| `election_results.csv` | 2.4GB | ~8M | Individual candidate votes by precinct |
| `municipal_barangay_tally.csv` | 938MB | ~3M | Municipal and barangay-level tallies |
| `precincts.csv` | 14MB | ~110K | Precinct details with turnout data |
| `contest_stats.csv` | 66MB | ~500K | Contest-level statistics |
| `barangay_summary.csv` | 2.6MB | ~42K | Barangay-level summaries |
| `overseas_results.csv` | 5MB | ~50K | Overseas voting results |

## 🔧 Configuration

### Environment Variables (.env)
The setup script creates a comprehensive `.env` file with all necessary variables:

```bash
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
```

### Terraform Configuration (terraform.tfvars)
```hcl
project_id             = "your-gcp-project-id"
service_account_email  = "dbt-election-analytics@your-project.iam.gserviceaccount.com"
region                = "us-central1"
environment           = "dev"

# Optional features
enable_scheduling     = true
enable_monitoring     = true
enable_data_transfer  = false
```

## 🛠️ Components

### 1. Data Collection Engine
- **Asynchronous scraping** with `asyncio` and `aiohttp`
- **Complete geographic coverage** across all Philippine regions
- **Overseas voting support** for international precincts
- **Robust error handling** and retry mechanisms
- **Deduplication system** to prevent data redundancy

### 2. Data Processing Pipeline
- **JSON to CSV conversion** for 10 structured datasets
- **Data validation** and quality checks
- **Schema standardization** for BigQuery compatibility
- **Geographic hierarchy** preservation

### 3. Cloud Infrastructure (Terraform)
- **BigQuery datasets**: Raw data, dbt transformations, analytics
- **Cloud Storage buckets**: Data staging and dbt artifacts
- **IAM permissions**: Service account with necessary roles
- **Optional features**: Scheduling, monitoring, data transfer jobs
- **Infrastructure as Code**: Version-controlled, reproducible deployments

### 4. Data Transformation (dbt)
- **Staging models**: Data cleaning and standardization
  - `stg_election_results`: Cleaned election results with derived fields
  - `stg_precincts`: Enhanced precinct data with turnout categories
- **Intermediate models**: Business logic and calculations
  - `int_candidate_performance`: Candidate metrics and rankings
  - `int_geographic_analysis`: Geographic turnout and vote concentration
- **Mart models**: Analytics-ready tables
  - `mart_senate_results`: Senate election analysis with winners
  - `mart_turnout_analysis`: Multi-level turnout statistics

## 📊 Analytics Capabilities

### Election Analysis
- **Candidate performance** across geographic levels
- **Vote share analysis** and ranking systems
- **Turnout patterns** by region, province, municipality
- **Geographic vote concentration** indices
- **Winner determination** for all contests

### Data Quality
- **Automated testing** with dbt tests
- **Data freshness** monitoring
- **Schema validation** for all tables
- **Referential integrity** checks
- **Statistical outlier** detection

### Visualization Ready
- **Pre-aggregated tables** for dashboard consumption
- **Geographic hierarchies** for mapping applications
- **Time-series ready** data structures
- **API-friendly** normalized schemas

## 🚀 Deployment Guide

### Step-by-Step Deployment

1. **Environment Setup**
   ```bash
   git clone <repository>
   cd 2025-comelec-national-and-local-election
   ./setup_environment.sh
   source venv/bin/activate
   ```

2. **Configure GCP**
   ```bash
   # Place service account key in gcp-credentials/
   # Update .env file with your project details
   nano .env
   ```

3. **Deploy Infrastructure**
   ```bash
   cd terraform
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your details
   ./deploy.sh
   ```

4. **Upload Data**
   ```bash
   cd .. && python gcp_upload_pipeline.py
   ```

5. **Run Transformations**
   ```bash
   cd dbt_election_analytics
   dbt deps && dbt run && dbt test
   ```

6. **Generate Documentation**
   ```bash
   dbt docs generate && dbt docs serve
   ```

## 🔍 Analysis Examples

### Senate Election Winners
```sql
SELECT 
  candidate_name,
  party,
  total_votes,
  vote_percentage,
  rank_national
FROM `your-project.philippines_election_2025_analytics.mart_senate_results`
WHERE is_winner = true
ORDER BY rank_national;
```

### Regional Turnout Analysis
```sql
SELECT 
  region,
  avg_turnout_percentage,
  total_registered_voters,
  total_actual_voters,
  turnout_rank
FROM `your-project.philippines_election_2025_analytics.mart_turnout_analysis`
WHERE geographic_level = 'region'
ORDER BY avg_turnout_percentage DESC;
```

### Top Performing Candidates by Province
```sql
SELECT 
  province,
  candidate_name,
  contest_name,
  total_votes,
  avg_vote_percentage,
  precincts_won
FROM `your-project.philippines_election_2025_dbt.int_candidate_performance`
WHERE province_rank <= 3
ORDER BY province, contest_name, province_rank;
```

## 🔧 Advanced Features

### Automated Scheduling
- **Daily dbt runs** via Cloud Scheduler
- **Data quality monitoring** with alerts
- **Incremental data processing** for updates

### Monitoring & Alerting
- **Log-based metrics** for dbt test failures
- **Email notifications** for data quality issues
- **Performance monitoring** for query optimization

### Data Governance
- **Column-level lineage** through dbt documentation
- **Data quality tests** at multiple levels
- **Schema evolution** tracking
- **Access control** via BigQuery IAM

## 📚 Documentation

- **[Terraform README](terraform/README.md)**: Infrastructure deployment guide
- **[dbt Documentation](README_GCP_DBT.md)**: Data transformation details
- **dbt Docs**: Auto-generated documentation (run `dbt docs serve`)
- **BigQuery Console**: Explore datasets and run queries
- **[Cleanup Summary](cleanup_summary.md)**: Recent project cleanup details

## 🧹 Recent Updates

### Project Cleanup (Latest)
- ✅ **Removed duplicate scripts**: Consolidated data processing logic
- ✅ **Enhanced requirements.txt**: Comprehensive dependency management
- ✅ **Automated setup script**: One-command environment setup
- ✅ **Improved .gitignore**: Better security and performance
- ✅ **Streamlined structure**: Clear separation of concerns
- ✅ **Updated documentation**: Reflects current architecture

### Key Improvements
- **Single source of truth** for each function
- **Production-ready** dependency management
- **Automated environment** setup and validation
- **Comprehensive security** rules and best practices
- **Clear project structure** aligned with data engineering standards

## 🤝 Contributing

1. **Data Collection**: Enhance scraping efficiency or add new data sources
2. **dbt Models**: Create new analytics models or improve existing ones
3. **Infrastructure**: Optimize Terraform configurations or add new resources
4. **Analysis**: Contribute analysis scripts or visualization examples

## 📄 License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## 🙏 Acknowledgments

- **COMELEC** for providing comprehensive election data
- **dbt Labs** for the excellent transformation framework
- **Google Cloud** for robust data infrastructure
- **Terraform** for infrastructure as code capabilities

## ⚠️ Disclaimer

This tool is for educational and research purposes only. Make sure to respect COMELEC's terms of service and rate limits when using this scraper.