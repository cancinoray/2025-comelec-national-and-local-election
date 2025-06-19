output "bigquery_datasets" {
  description = "Information about created BigQuery datasets"
  value = {
    raw_data = {
      dataset_id = google_bigquery_dataset.raw_election_data.dataset_id
      location   = google_bigquery_dataset.raw_election_data.location
      self_link  = google_bigquery_dataset.raw_election_data.self_link
    }
    dbt_transformed = {
      dataset_id = google_bigquery_dataset.dbt_election_data.dataset_id
      location   = google_bigquery_dataset.dbt_election_data.location
      self_link  = google_bigquery_dataset.dbt_election_data.self_link
    }
    analytics = {
      dataset_id = google_bigquery_dataset.election_analytics.dataset_id
      location   = google_bigquery_dataset.election_analytics.location
      self_link  = google_bigquery_dataset.election_analytics.self_link
    }
  }
}

output "storage_buckets" {
  description = "Information about created Cloud Storage buckets"
  value = {
    data_staging = {
      name      = google_storage_bucket.election_data_staging.name
      url       = google_storage_bucket.election_data_staging.url
      self_link = google_storage_bucket.election_data_staging.self_link
    }
    dbt_artifacts = {
      name      = google_storage_bucket.dbt_artifacts.name
      url       = google_storage_bucket.dbt_artifacts.url
      self_link = google_storage_bucket.dbt_artifacts.self_link
    }
  }
}

output "project_services" {
  description = "List of enabled GCP services"
  value       = [for service in google_project_service.required_apis : service.service]
}

output "service_account_permissions" {
  description = "IAM roles assigned to the service account"
  value = [
    google_project_iam_member.bigquery_admin.role,
    google_project_iam_member.storage_admin.role,
    google_project_iam_member.dataflow_admin.role,
    google_project_iam_member.composer_worker.role
  ]
}

output "bigquery_console_urls" {
  description = "URLs to access BigQuery datasets in the console"
  value = {
    raw_data = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.raw_election_data.dataset_id}"
    dbt_transformed = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.dbt_election_data.dataset_id}"
    analytics = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.election_analytics.dataset_id}"
  }
}

output "monitoring_dashboard_url" {
  description = "URL to the monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}"
}

output "cloud_storage_console_urls" {
  description = "URLs to access Cloud Storage buckets in the console"
  value = {
    data_staging = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.election_data_staging.name}?project=${var.project_id}"
    dbt_artifacts = "https://console.cloud.google.com/storage/browser/${google_storage_bucket.dbt_artifacts.name}?project=${var.project_id}"
  }
}

output "scheduler_job_info" {
  description = "Information about the scheduled dbt job"
  value = var.enable_scheduling ? {
    name     = google_cloud_scheduler_job.dbt_daily_run[0].name
    schedule = google_cloud_scheduler_job.dbt_daily_run[0].schedule
    timezone = google_cloud_scheduler_job.dbt_daily_run[0].time_zone
  } : null
}

output "next_steps" {
  description = "Next steps after Terraform deployment"
  value = <<-EOT
    🎉 Infrastructure deployed successfully!
    
    Next steps:
    1. Upload data: python gcp_upload_pipeline.py
    2. Run dbt: cd dbt_election_analytics && dbt run
    3. View BigQuery datasets: ${join(", ", values(local.bigquery_console_urls))}
    4. Monitor data quality: ${local.monitoring_dashboard_url}
    
    Resources created:
    - BigQuery datasets: ${length(local.bigquery_datasets)} datasets
    - Storage buckets: ${length(local.storage_buckets)} buckets
    - IAM permissions: Service account configured
    ${var.enable_scheduling ? "- Scheduled job: Daily dbt runs enabled" : ""}
    ${var.enable_monitoring ? "- Monitoring: Alerts configured" : ""}
  EOT
}

locals {
  bigquery_console_urls = {
    raw_data = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.raw_election_data.dataset_id}"
    dbt_transformed = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.dbt_election_data.dataset_id}"
    analytics = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.election_analytics.dataset_id}"
  }
  
  bigquery_datasets = {
    raw_data = google_bigquery_dataset.raw_election_data
    dbt_transformed = google_bigquery_dataset.dbt_election_data
    analytics = google_bigquery_dataset.election_analytics
  }
  
  storage_buckets = {
    data_staging = google_storage_bucket.election_data_staging
    dbt_artifacts = google_storage_bucket.dbt_artifacts
  }
  
  monitoring_dashboard_url = "https://console.cloud.google.com/monitoring/dashboards?project=${var.project_id}"
}
