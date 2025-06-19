# GCP BigQuery + dbt Pipeline for Philippines Election Data

This setup creates a comprehensive data pipeline that uploads your election data to Google Cloud BigQuery and uses dbt for data transformations and analytics.

## 🏗️ Architecture Overview

```
Raw CSV Data → BigQuery (Raw Tables) → dbt Transformations → Analytics Tables
```

### Data Flow:
1. **Raw Data Layer**: CSV files uploaded to BigQuery as source tables
2. **Staging Layer**: Clean and standardize data with dbt
3. **Intermediate Layer**: Create reusable business logic components
4. **Marts Layer**: Final analytics tables for reporting and visualization

## 📋 Prerequisites

1. **GCP Account** with billing enabled
2. **GCP Project** with BigQuery API enabled
3. **Python 3.8+** installed
4. **gcloud CLI** installed and configured

## 🚀 Quick Setup

### 1. Set Environment Variables
```bash
export GCP_PROJECT_ID="your-gcp-project-id"
```

### 2. Run Setup Script
```bash
./setup_gcp_dbt.sh
```

This script will:
- Install required Python packages
- Enable necessary GCP APIs
- Create service account and authentication keys
- Configure dbt profiles
- Install dbt packages

### 3. Upload Data to BigQuery
```bash
python gcp_upload_pipeline.py
```

### 4. Run dbt Transformations
```bash
cd dbt_election_analytics
dbt run
```

## 📊 Data Models

### Staging Models (`models/staging/`)
- `stg_election_results`: Cleaned election results with derived fields
- `stg_precincts`: Standardized precinct information with turnout metrics

### Intermediate Models (`models/intermediate/`)
- `int_candidate_performance`: Aggregated candidate statistics and rankings
- `int_geographic_analysis`: Geographic turnout and voting pattern analysis

### Marts Models (`models/marts/`)
- `mart_senate_results`: Comprehensive Senate election analysis
- `mart_turnout_analysis`: Multi-level turnout analysis (regional/provincial/municipal)

## 🔍 Key Features

### Data Quality
- **Schema validation** for all BigQuery tables
- **Data tests** using dbt_utils and dbt_expectations
- **Null checks** and **range validations**

### Analytics Capabilities
- **Candidate performance metrics** (vote share, rankings, geographic spread)
- **Turnout analysis** by geographic levels
- **Vote concentration indices**
- **Regional stronghold identification**

### Transformations
- **Data cleaning** (standardized names, party affiliations)
- **Derived metrics** (turnout categories, performance tiers)
- **Geographic hierarchies** (region → province → municipality → barangay)

## 📈 Available Analytics

### Senate Analysis
```sql
SELECT 
    clean_candidate_name,
    party,
    total_votes,
    vote_rank,
    is_winner,
    performance_tier,
    stronghold_regions_count
FROM mart_senate_results
WHERE is_winner = true
ORDER BY vote_rank;
```

### Turnout Analysis
```sql
SELECT 
    region,
    region_calculated_turnout_rate,
    region_turnout_category,
    high_engagement_region
FROM mart_turnout_analysis
ORDER BY region_calculated_turnout_rate DESC;
```

## 🛠️ dbt Commands

### Development
```bash
# Test dbt connection
dbt debug

# Install packages
dbt deps

# Run all models
dbt run

# Run specific model
dbt run --select mart_senate_results

# Test data quality
dbt test

# Generate documentation
dbt docs generate
dbt docs serve
```

### Production
```bash
# Run with production profile
dbt run --target prod

# Full refresh (rebuild all tables)
dbt run --full-refresh
```

## 📁 Project Structure

```
dbt_election_analytics/
├── dbt_project.yml          # dbt project configuration
├── profiles.yml             # BigQuery connection settings
├── packages.yml             # dbt package dependencies
├── models/
│   ├── staging/             # Raw data cleaning
│   ├── intermediate/        # Business logic components
│   └── marts/              # Final analytics tables
└── tests/                  # Custom data tests
```

## 🔧 Configuration

### BigQuery Settings
- **Location**: US (configurable in profiles.yml)
- **Dataset**: `philippines_election_2025` (raw data)
- **dbt Dataset**: `philippines_election_2025_dbt` (transformed data)

### Performance Optimization
- **Staging models**: Materialized as views (fast, no storage cost)
- **Marts models**: Materialized as tables (fast queries, some storage cost)
- **Partitioning**: Can be added for large tables

## 🚨 Troubleshooting

### Common Issues

1. **Authentication Error**
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

2. **Permission Denied**
   - Ensure service account has BigQuery Admin role
   - Check if APIs are enabled

3. **dbt Connection Issues**
   - Verify `profiles.yml` has correct project ID
   - Check service account key path

4. **Large File Upload Timeouts**
   - Consider splitting large CSV files
   - Increase timeout in upload script

## 📊 Next Steps

1. **Visualization**: Connect Looker Studio or Tableau to BigQuery
2. **Scheduling**: Set up Cloud Composer/Airflow for automated runs
3. **Monitoring**: Add data quality alerts and monitoring
4. **ML**: Use BigQuery ML for predictive analytics
5. **Real-time**: Implement streaming updates with Pub/Sub

## 🤝 Contributing

To add new models or modify existing ones:
1. Create new `.sql` files in appropriate model directories
2. Update `schema.yml` files with documentation
3. Add tests for data quality
4. Run `dbt run` and `dbt test` to validate

## 📝 Documentation

Generate and view dbt documentation:
```bash
dbt docs generate
dbt docs serve
```

This creates an interactive documentation site with model lineage, column descriptions, and data quality test results.
