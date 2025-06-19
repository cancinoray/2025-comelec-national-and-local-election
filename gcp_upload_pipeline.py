#!/usr/bin/env python3
"""
GCP BigQuery Upload Pipeline for Philippines Election Data
Uploads CSV datasets to BigQuery with proper schema definitions
"""

import os
import pandas as pd
from google.cloud import bigquery
from google.cloud.exceptions import NotFound
import logging
from typing import Dict, List
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ElectionDataUploader:
    def __init__(self, project_id: str, dataset_id: str = "philippines_election_2025"):
        """
        Initialize the uploader with GCP project and dataset information
        
        Args:
            project_id: GCP project ID
            dataset_id: BigQuery dataset ID
        """
        self.project_id = project_id
        self.dataset_id = dataset_id
        self.client = bigquery.Client(project=project_id)
        self.dataset_ref = self.client.dataset(dataset_id)
        
    def create_dataset(self):
        """Create the BigQuery dataset if it doesn't exist"""
        try:
            self.client.get_dataset(self.dataset_ref)
            logger.info(f"Dataset {self.dataset_id} already exists")
        except NotFound:
            dataset = bigquery.Dataset(self.dataset_ref)
            dataset.location = "US"  # Change to your preferred location
            dataset.description = "Philippines 2025 COMELEC Election Data"
            dataset = self.client.create_dataset(dataset)
            logger.info(f"Created dataset {self.dataset_id}")
    
    def get_table_schemas(self) -> Dict[str, List[bigquery.SchemaField]]:
        """Define BigQuery schemas for each table"""
        schemas = {
            "election_results": [
                bigquery.SchemaField("precinct_id", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_code", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("candidate_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("party", "STRING", mode="NULLABLE"),
                bigquery.SchemaField("votes", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("percentage", "FLOAT", mode="REQUIRED"),
                bigquery.SchemaField("election_level", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("over_votes", "INTEGER", mode="NULLABLE"),
                bigquery.SchemaField("under_votes", "INTEGER", mode="NULLABLE"),
                bigquery.SchemaField("valid_votes", "INTEGER", mode="NULLABLE"),
                bigquery.SchemaField("obtained_votes", "INTEGER", mode="NULLABLE"),
            ],
            "precincts": [
                bigquery.SchemaField("precinct_id", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("machine_id", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("region", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("province", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("municipality", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("barangay", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("voting_center", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("precinct_in_cluster", "STRING", mode="NULLABLE"),
                bigquery.SchemaField("registered_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("actual_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("valid_ballots", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("turnout_percentage", "FLOAT", mode="REQUIRED"),
                bigquery.SchemaField("abstentions", "INTEGER", mode="NULLABLE"),
                bigquery.SchemaField("total_er_received", "FLOAT", mode="NULLABLE"),
            ],
            "municipal_barangay_tally": [
                bigquery.SchemaField("region", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("province", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("municipality", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("barangay", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_code", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("candidate_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("party", "STRING", mode="NULLABLE"),
                bigquery.SchemaField("total_votes", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("percentage", "FLOAT", mode="REQUIRED"),
            ],
            "provincial_municipal_tally": [
                bigquery.SchemaField("region", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("province", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("municipality", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_code", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("candidate_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("party", "STRING", mode="NULLABLE"),
                bigquery.SchemaField("total_votes", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("percentage", "FLOAT", mode="REQUIRED"),
            ],
            "regional_vote_tally": [
                bigquery.SchemaField("region", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_code", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("candidate_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("party", "STRING", mode="NULLABLE"),
                bigquery.SchemaField("total_votes", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("percentage", "FLOAT", mode="REQUIRED"),
            ],
            "contest_stats": [
                bigquery.SchemaField("contest_code", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("election_level", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("total_candidates", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_votes", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_precincts", "INTEGER", mode="REQUIRED"),
            ],
            "overseas_results": [
                bigquery.SchemaField("precinct_id", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_code", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("contest_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("candidate_name", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("party", "STRING", mode="NULLABLE"),
                bigquery.SchemaField("votes", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("percentage", "FLOAT", mode="REQUIRED"),
                bigquery.SchemaField("country", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("city", "STRING", mode="REQUIRED"),
            ],
            "barangay_summary": [
                bigquery.SchemaField("region", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("province", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("municipality", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("barangay", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("total_registered_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_actual_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("turnout_percentage", "FLOAT", mode="REQUIRED"),
                bigquery.SchemaField("total_precincts", "INTEGER", mode="REQUIRED"),
            ],
            "municipal_summary": [
                bigquery.SchemaField("region", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("province", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("municipality", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("total_registered_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_actual_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("turnout_percentage", "FLOAT", mode="REQUIRED"),
                bigquery.SchemaField("total_barangays", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_precincts", "INTEGER", mode="REQUIRED"),
            ],
            "provincial_summary": [
                bigquery.SchemaField("region", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("province", "STRING", mode="REQUIRED"),
                bigquery.SchemaField("total_registered_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_actual_voters", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("turnout_percentage", "FLOAT", mode="REQUIRED"),
                bigquery.SchemaField("total_municipalities", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_barangays", "INTEGER", mode="REQUIRED"),
                bigquery.SchemaField("total_precincts", "INTEGER", mode="REQUIRED"),
            ],
        }
        return schemas
    
    def upload_csv_to_bigquery(self, csv_file_path: str, table_name: str, schema: List[bigquery.SchemaField]):
        """
        Upload a CSV file to BigQuery
        
        Args:
            csv_file_path: Path to the CSV file
            table_name: Name of the BigQuery table
            schema: BigQuery schema for the table
        """
        table_ref = self.dataset_ref.table(table_name)
        
        # Configure the load job
        job_config = bigquery.LoadJobConfig(
            schema=schema,
            skip_leading_rows=1,  # Skip header row
            source_format=bigquery.SourceFormat.CSV,
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,  # Overwrite existing data
            allow_quoted_newlines=True,
            allow_jagged_rows=False,
            max_bad_records=100,  # Allow some bad records
        )
        
        logger.info(f"Starting upload of {csv_file_path} to {table_name}")
        
        with open(csv_file_path, "rb") as source_file:
            job = self.client.load_table_from_file(
                source_file, table_ref, job_config=job_config
            )
        
        # Wait for the job to complete
        job.result()
        
        # Get the table info
        table = self.client.get_table(table_ref)
        logger.info(f"Loaded {table.num_rows} rows into {table_name}")
        
        if job.errors:
            logger.warning(f"Errors during upload to {table_name}: {job.errors}")
    
    def upload_all_datasets(self, csv_dir: str = "./csv_datasets"):
        """Upload all CSV datasets to BigQuery"""
        self.create_dataset()
        schemas = self.get_table_schemas()
        csv_path = Path(csv_dir)
        
        # Map CSV files to table names (remove .csv extension)
        csv_files = [f for f in csv_path.glob("*.csv")]
        
        for csv_file in csv_files:
            table_name = csv_file.stem  # filename without extension
            
            if table_name in schemas:
                try:
                    self.upload_csv_to_bigquery(
                        str(csv_file), 
                        table_name, 
                        schemas[table_name]
                    )
                except Exception as e:
                    logger.error(f"Failed to upload {table_name}: {str(e)}")
            else:
                logger.warning(f"No schema defined for {table_name}, skipping")

def main():
    """Main function to run the upload pipeline"""
    # Set your GCP project ID here
    PROJECT_ID = "your-gcp-project-id"  # Replace with your actual project ID
    
    # Initialize uploader
    uploader = ElectionDataUploader(PROJECT_ID)
    
    # Upload all datasets
    uploader.upload_all_datasets()
    
    logger.info("Upload pipeline completed!")

if __name__ == "__main__":
    main()
