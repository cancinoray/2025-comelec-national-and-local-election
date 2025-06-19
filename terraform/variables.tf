variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "credentials_file" {
  description = "Path to the service account credentials JSON file"
  type        = string
  default     = "../gcp-credentials/service-account-key.json"
}

variable "service_account_email" {
  description = "Email of the service account for dbt and data operations"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for resources"
  type        = string
  default     = "us-central1-a"
}

variable "bigquery_location" {
  description = "Location for BigQuery datasets"
  type        = string
  default     = "US"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "enable_scheduling" {
  description = "Enable Cloud Scheduler for automated dbt runs"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = false
}

variable "dbt_webhook_url" {
  description = "Webhook URL for triggering dbt runs (if scheduling is enabled)"
  type        = string
  default     = ""
}

variable "notification_channels" {
  description = "List of notification channels for alerts"
  type        = list(string)
  default     = []
}

variable "enable_data_transfer" {
  description = "Enable BigQuery Data Transfer Service for automated data loading"
  type        = bool
  default     = false
}

variable "bigquery_tables" {
  description = "Configuration for BigQuery tables to be created"
  type = map(object({
    dataset_id  = string
    table_id    = string
    description = string
    schema_file = string
  }))
  default = {
    election_results = {
      dataset_id  = "philippines_election_2025"
      table_id    = "election_results"
      description = "Detailed election results by precinct and candidate"
      schema_file = "schemas/election_results.json"
    }
    precincts = {
      dataset_id  = "philippines_election_2025"
      table_id    = "precincts"
      description = "Precinct information and voter turnout data"
      schema_file = "schemas/precincts.json"
    }
    municipal_barangay_tally = {
      dataset_id  = "philippines_election_2025"
      table_id    = "municipal_barangay_tally"
      description = "Vote tallies aggregated by municipality and barangay"
      schema_file = "schemas/municipal_barangay_tally.json"
    }
    provincial_municipal_tally = {
      dataset_id  = "philippines_election_2025"
      table_id    = "provincial_municipal_tally"
      description = "Vote tallies aggregated by province and municipality"
      schema_file = "schemas/provincial_municipal_tally.json"
    }
    regional_vote_tally = {
      dataset_id  = "philippines_election_2025"
      table_id    = "regional_vote_tally"
      description = "Vote tallies aggregated by region"
      schema_file = "schemas/regional_vote_tally.json"
    }
    contest_stats = {
      dataset_id  = "philippines_election_2025"
      table_id    = "contest_stats"
      description = "Statistics about each contest/position"
      schema_file = "schemas/contest_stats.json"
    }
    overseas_results = {
      dataset_id  = "philippines_election_2025"
      table_id    = "overseas_results"
      description = "Election results from overseas voting"
      schema_file = "schemas/overseas_results.json"
    }
    barangay_summary = {
      dataset_id  = "philippines_election_2025"
      table_id    = "barangay_summary"
      description = "Summary statistics by barangay"
      schema_file = "schemas/barangay_summary.json"
    }
    municipal_summary = {
      dataset_id  = "philippines_election_2025"
      table_id    = "municipal_summary"
      description = "Summary statistics by municipality"
      schema_file = "schemas/municipal_summary.json"
    }
    provincial_summary = {
      dataset_id  = "philippines_election_2025"
      table_id    = "provincial_summary"
      description = "Summary statistics by province"
      schema_file = "schemas/provincial_summary.json"
    }
  }
}
