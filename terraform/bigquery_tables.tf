# BigQuery tables with schemas
resource "google_bigquery_table" "election_tables" {
  for_each = var.bigquery_tables

  dataset_id = each.value.dataset_id
  table_id   = each.value.table_id

  description = each.value.description

  labels = {
    environment = var.environment
    project     = "election-analytics"
    data_type   = "raw"
  }

  schema = file("${path.module}/${each.value.schema_file}")

  depends_on = [
    google_bigquery_dataset.raw_election_data,
    google_project_service.required_apis
  ]
}

# Data transfer jobs for automated data loading (optional)
resource "google_bigquery_data_transfer_config" "election_data_transfer" {
  count = var.enable_data_transfer ? 1 : 0

  display_name           = "Election Data Transfer"
  location               = var.bigquery_location
  data_source_id         = "google_cloud_storage"
  destination_dataset_id = google_bigquery_dataset.raw_election_data.dataset_id
  
  schedule = "every day 02:00"
  
  params = {
    data_path_template              = "gs://${google_storage_bucket.election_data_staging.name}/daily_updates/*.csv"
    destination_table_name_template = "election_results_{run_date}"
    file_format                     = "CSV"
    max_bad_records                 = 100
    skip_leading_rows               = 1
    write_disposition               = "WRITE_APPEND"
  }

  service_account_name = var.service_account_email

  depends_on = [
    google_project_service.required_apis,
    google_storage_bucket.election_data_staging
  ]
}

# Views for easier data access
resource "google_bigquery_table" "election_results_view" {
  dataset_id = google_bigquery_dataset.raw_election_data.dataset_id
  table_id   = "election_results_latest"

  description = "Latest election results view with data quality filters"

  view {
    query = <<-SQL
      SELECT 
        precinct_id,
        contest_code,
        contest_name,
        candidate_name,
        party,
        votes,
        percentage,
        election_level,
        over_votes,
        under_votes,
        valid_votes,
        obtained_votes
      FROM `${var.project_id}.${google_bigquery_dataset.raw_election_data.dataset_id}.election_results`
      WHERE votes >= 0 
        AND percentage >= 0 
        AND percentage <= 100
        AND precinct_id IS NOT NULL
        AND candidate_name IS NOT NULL
      ORDER BY precinct_id, contest_code, votes DESC
    SQL
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.election_tables]
}

resource "google_bigquery_table" "precincts_enhanced_view" {
  dataset_id = google_bigquery_dataset.raw_election_data.dataset_id
  table_id   = "precincts_enhanced"

  description = "Enhanced precincts view with calculated fields"

  view {
    query = <<-SQL
      SELECT 
        *,
        CASE 
          WHEN turnout_percentage >= 90 THEN 'Very High'
          WHEN turnout_percentage >= 80 THEN 'High'
          WHEN turnout_percentage >= 70 THEN 'Medium'
          WHEN turnout_percentage >= 60 THEN 'Low'
          ELSE 'Very Low'
        END as turnout_category,
        actual_voters - valid_ballots as invalid_ballots,
        registered_voters - actual_voters as non_voters,
        REGEXP_EXTRACT(region, r'REGION (\w+)') as region_code
      FROM `${var.project_id}.${google_bigquery_dataset.raw_election_data.dataset_id}.precincts`
      WHERE registered_voters > 0 
        AND actual_voters >= 0
        AND turnout_percentage BETWEEN 0 AND 100
    SQL
    use_legacy_sql = false
  }

  depends_on = [google_bigquery_table.election_tables]
}

# Materialized view for performance (if supported)
resource "google_bigquery_table" "candidate_summary_materialized" {
  dataset_id = google_bigquery_dataset.raw_election_data.dataset_id
  table_id   = "candidate_summary_mv"

  description = "Materialized view of candidate vote summaries"

  materialized_view {
    query = <<-SQL
      SELECT 
        contest_code,
        contest_name,
        candidate_name,
        party,
        SUM(votes) as total_votes,
        COUNT(DISTINCT precinct_id) as precincts_contested,
        AVG(percentage) as avg_percentage,
        MIN(percentage) as min_percentage,
        MAX(percentage) as max_percentage
      FROM `${var.project_id}.${google_bigquery_dataset.raw_election_data.dataset_id}.election_results`
      WHERE votes >= 0
      GROUP BY 1, 2, 3, 4
    SQL
    enable_refresh = true
    refresh_interval_ms = 3600000  # Refresh every hour
  }

  depends_on = [google_bigquery_table.election_tables]
}
