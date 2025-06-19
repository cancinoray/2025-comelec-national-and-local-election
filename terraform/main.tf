terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

provider "google-beta" {
  credentials = file(var.credentials_file)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "bigquery.googleapis.com",
    "bigquerydatatransfer.googleapis.com",
    "storage.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "composer.googleapis.com",
    "dataflow.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# BigQuery datasets
resource "google_bigquery_dataset" "raw_election_data" {
  dataset_id                 = "philippines_election_2025"
  friendly_name              = "Philippines Election 2025 - Raw Data"
  description                = "Raw election data from COMELEC 2025"
  location                   = var.bigquery_location
  default_table_expiration_ms = null

  labels = {
    environment = var.environment
    project     = "election-analytics"
    data_type   = "raw"
  }

  access {
    role          = "OWNER"
    user_by_email = var.service_account_email
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "dbt_election_data" {
  dataset_id                 = "philippines_election_2025_dbt"
  friendly_name              = "Philippines Election 2025 - dbt Transformed"
  description                = "Transformed election data using dbt"
  location                   = var.bigquery_location
  default_table_expiration_ms = null

  labels = {
    environment = var.environment
    project     = "election-analytics"
    data_type   = "transformed"
  }

  access {
    role          = "OWNER"
    user_by_email = var.service_account_email
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  access {
    role          = "WRITER"
    special_group = "projectWriters"
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_dataset" "election_analytics" {
  dataset_id                 = "philippines_election_2025_analytics"
  friendly_name              = "Philippines Election 2025 - Analytics"
  description                = "Final analytics tables for reporting and visualization"
  location                   = var.bigquery_location
  default_table_expiration_ms = null

  labels = {
    environment = var.environment
    project     = "election-analytics"
    data_type   = "analytics"
  }

  access {
    role          = "OWNER"
    user_by_email = var.service_account_email
  }

  access {
    role          = "READER"
    special_group = "projectReaders"
  }

  depends_on = [google_project_service.required_apis]
}

# Cloud Storage bucket for data staging and backups
resource "google_storage_bucket" "election_data_staging" {
  name          = "${var.project_id}-election-data-staging"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age                = 30
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    environment = var.environment
    project     = "election-analytics"
    purpose     = "data-staging"
  }

  depends_on = [google_project_service.required_apis]
}

# Cloud Storage bucket for dbt artifacts and logs
resource "google_storage_bucket" "dbt_artifacts" {
  name          = "${var.project_id}-dbt-artifacts"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    project     = "election-analytics"
    purpose     = "dbt-artifacts"
  }

  depends_on = [google_project_service.required_apis]
}

# IAM bindings for the service account
resource "google_project_iam_member" "bigquery_admin" {
  project = var.project_id
  role    = "roles/bigquery.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "dataflow_admin" {
  project = var.project_id
  role    = "roles/dataflow.admin"
  member  = "serviceAccount:${var.service_account_email}"
}

resource "google_project_iam_member" "composer_worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${var.service_account_email}"
}

# Cloud Scheduler for automated dbt runs (optional)
resource "google_cloud_scheduler_job" "dbt_daily_run" {
  count = var.enable_scheduling ? 1 : 0

  name             = "dbt-election-analytics-daily"
  description      = "Daily dbt run for election analytics"
  schedule         = "0 6 * * *"  # Daily at 6 AM
  time_zone        = "Asia/Manila"
  attempt_deadline = "320s"

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = var.dbt_webhook_url

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      command = "dbt run"
      project = "election_analytics"
    }))
  }

  depends_on = [google_project_service.required_apis]
}

# Monitoring - Log-based metrics for data quality
resource "google_logging_metric" "dbt_test_failures" {
  name   = "dbt_test_failures"
  filter = "resource.type=\"cloud_function\" AND jsonPayload.message=~\".*FAIL.*\" AND jsonPayload.source=\"dbt\""

  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    display_name = "dbt Test Failures"
  }

  label_extractors = {
    "test_name" = "EXTRACT(jsonPayload.test_name)"
  }

  depends_on = [google_project_service.required_apis]
}

# Alerting policy for data quality issues
resource "google_monitoring_alert_policy" "dbt_test_failures" {
  count = var.enable_monitoring ? 1 : 0

  display_name = "dbt Test Failures Alert"
  combiner     = "OR"

  conditions {
    display_name = "dbt test failure condition"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/dbt_test_failures\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "1800s"
  }

  depends_on = [google_project_service.required_apis]
}
