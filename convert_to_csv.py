import json
import csv
import os
import re
from pathlib import Path

def extract_location_parts(location_str):
    """Extract region, province, municipality, barangay from location string"""
    parts = [part.strip() for part in location_str.split(',')]
    
    region = parts[0] if len(parts) > 0 else ""
    province = parts[1] if len(parts) > 1 else ""
    municipality = parts[2] if len(parts) > 2 else ""
    barangay = parts[3] if len(parts) > 3 else ""
    
    return region, province, municipality, barangay

def extract_party_from_name(candidate_name):
    """Extract party affiliation from candidate name"""
    match = re.search(r'\(([^)]+)\)$', candidate_name)
    if match:
        return match.group(1)
    return ""

def clean_candidate_name(candidate_name):
    """Remove party affiliation from candidate name"""
    return re.sub(r'\s*\([^)]+\)$', '', candidate_name).strip()

def process_json_files(election_data_dir, output_dir):
    """Process all JSON files and create CSV datasets"""
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    # Initialize CSV files
    precincts_file = open(os.path.join(output_dir, 'precincts.csv'), 'w', newline='', encoding='utf-8')
    results_file = open(os.path.join(output_dir, 'election_results.csv'), 'w', newline='', encoding='utf-8')
    stats_file = open(os.path.join(output_dir, 'contest_stats.csv'), 'w', newline='', encoding='utf-8')
    
    # Create CSV writers
    precincts_writer = csv.writer(precincts_file)
    results_writer = csv.writer(results_file)
    stats_writer = csv.writer(stats_file)
    
    # Write headers
    precincts_writer.writerow([
        'precinct_id', 'machine_id', 'region', 'province', 'municipality', 
        'barangay', 'voting_center', 'precinct_in_cluster', 'registered_voters', 
        'actual_voters', 'valid_ballots', 'turnout_percentage', 'abstentions', 
        'total_er_received'
    ])
    
    results_writer.writerow([
        'precinct_id', 'contest_code', 'contest_name', 'candidate_name', 
        'party', 'votes', 'percentage', 'election_level', 'over_votes', 
        'under_votes', 'valid_votes', 'obtained_votes'
    ])
    
    stats_writer.writerow([
        'precinct_id', 'contest_code', 'contest_name', 'election_level', 
        'over_votes', 'under_votes', 'valid_votes', 'obtained_votes'
    ])
    
    # Process all JSON files
    json_files_processed = 0
    
    for root, dirs, files in os.walk(election_data_dir):
        for file in files:
            if file.endswith('.json'):
                file_path = os.path.join(root, file)
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    
                    # Extract precinct information
                    info = data.get('information', {})
                    precinct_id = info.get('precinctId', '')
                    machine_id = info.get('machineId', '')
                    location = info.get('location', '')
                    voting_center = info.get('votingCenter', '')
                    precinct_in_cluster = info.get('precinctInCluster', '')
                    
                    region, province, municipality, barangay = extract_location_parts(location)
                    
                    # Write precinct data
                    precincts_writer.writerow([
                        precinct_id,
                        machine_id,
                        region,
                        province,
                        municipality,
                        barangay,
                        voting_center,
                        precinct_in_cluster,
                        info.get('numberOfRegisteredVoters', 0),
                        info.get('numberOfActuallyVoters', 0),
                        info.get('numberOfValidBallot', 0),
                        info.get('turnout', 0.0),
                        info.get('abstentions', 0),
                        data.get('totalErReceived', 0.0)
                    ])
                    
                    # Process national contests
                    for contest in data.get('national', []):
                        contest_code = contest.get('contestCode', '')
                        contest_name = contest.get('contestName', '')
                        statistics = contest.get('statistic', {})
                        
                        # Write contest statistics
                        stats_writer.writerow([
                            precinct_id,
                            contest_code,
                            contest_name,
                            'national',
                            statistics.get('overVotes', 0),
                            statistics.get('underVotes', 0),
                            statistics.get('validVotes', 0),
                            statistics.get('obtainedVotes', 0)
                        ])
                        
                        # Process candidates
                        candidates = contest.get('candidates', {}).get('candidates', [])
                        for candidate in candidates:
                            candidate_name = candidate.get('name', '')
                            party = extract_party_from_name(candidate_name)
                            clean_name = clean_candidate_name(candidate_name)
                            
                            results_writer.writerow([
                                precinct_id,
                                contest_code,
                                contest_name,
                                clean_name,
                                party,
                                candidate.get('votes', 0),
                                candidate.get('percentage', 0.0),
                                'national',
                                statistics.get('overVotes', 0),
                                statistics.get('underVotes', 0),
                                statistics.get('validVotes', 0),
                                statistics.get('obtainedVotes', 0)
                            ])
                    
                    # Process local contests
                    for contest in data.get('local', []):
                        contest_code = contest.get('contestCode', '')
                        contest_name = contest.get('contestName', '')
                        statistics = contest.get('statistic', {})
                        
                        # Write contest statistics
                        stats_writer.writerow([
                            precinct_id,
                            contest_code,
                            contest_name,
                            'local',
                            statistics.get('overVotes', 0),
                            statistics.get('underVotes', 0),
                            statistics.get('validVotes', 0),
                            statistics.get('obtainedVotes', 0)
                        ])
                        
                        # Process candidates
                        candidates = contest.get('candidates', {}).get('candidates', [])
                        for candidate in candidates:
                            candidate_name = candidate.get('name', '')
                            party = extract_party_from_name(candidate_name)
                            clean_name = clean_candidate_name(candidate_name)
                            
                            results_writer.writerow([
                                precinct_id,
                                contest_code,
                                contest_name,
                                clean_name,
                                party,
                                candidate.get('votes', 0),
                                candidate.get('percentage', 0.0),
                                'local',
                                statistics.get('overVotes', 0),
                                statistics.get('underVotes', 0),
                                statistics.get('validVotes', 0),
                                statistics.get('obtainedVotes', 0)
                            ])
                    
                    json_files_processed += 1
                    if json_files_processed % 100 == 0:
                        print(f"Processed {json_files_processed} files...")
                        
                except Exception as e:
                    print(f"Error processing {file_path}: {str(e)}")
                    continue
    
    # Close files
    precincts_file.close()
    results_file.close()
    stats_file.close()
    
    print(f"\nCompleted! Processed {json_files_processed} JSON files.")
    print(f"CSV files created in: {output_dir}")
    print("Files created:")
    print("- precincts.csv: Precinct/voting center information")
    print("- election_results.csv: Individual candidate results")
    print("- contest_stats.csv: Contest-level statistics")

def process_overseas_data(overseas_data_dir, output_dir):
    """Process overseas election data separately"""
    
    overseas_file = open(os.path.join(output_dir, 'overseas_results.csv'), 'w', newline='', encoding='utf-8')
    overseas_writer = csv.writer(overseas_file)
    
    # Write header
    overseas_writer.writerow([
        'region_code', 'country_region', 'voting_center', 'contest_code', 
        'contest_name', 'candidate_name', 'party', 'votes', 'percentage', 
        'registered_voters', 'actual_voters', 'turnout_percentage'
    ])
    
    for root, dirs, files in os.walk(overseas_data_dir):
        for file in files:
            if file.endswith('.json'):
                file_path = os.path.join(root, file)
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    
                    # Extract overseas information
                    info = data.get('information', {})
                    
                    # Process contests (similar structure to domestic)
                    for contest in data.get('national', []):
                        contest_code = contest.get('contestCode', '')
                        contest_name = contest.get('contestName', '')
                        
                        candidates = contest.get('candidates', {}).get('candidates', [])
                        for candidate in candidates:
                            candidate_name = candidate.get('name', '')
                            party = extract_party_from_name(candidate_name)
                            clean_name = clean_candidate_name(candidate_name)
                            
                            overseas_writer.writerow([
                                'R0OAV00',  # Overseas region code
                                Path(root).name,  # Country/region from folder name
                                info.get('votingCenter', ''),
                                contest_code,
                                contest_name,
                                clean_name,
                                party,
                                candidate.get('votes', 0),
                                candidate.get('percentage', 0.0),
                                info.get('numberOfRegisteredVoters', 0),
                                info.get('numberOfActuallyVoters', 0),
                                info.get('turnout', 0.0)
                            ])
                            
                except Exception as e:
                    print(f"Error processing overseas file {file_path}: {str(e)}")
                    continue
    
    overseas_file.close()
    print("- overseas_results.csv: Overseas voting results")

if __name__ == "__main__":
    # Set paths
    election_data_dir = "./election_data"
    overseas_data_dir = "./election_data_overseas"
    output_dir = "./csv_datasets"
    
    print("Starting conversion of election data to CSV format...")
    
    # Process domestic election data
    if os.path.exists(election_data_dir):
        process_json_files(election_data_dir, output_dir)
    
    # Process overseas election data
    if os.path.exists(overseas_data_dir):
        process_overseas_data(overseas_data_dir, output_dir)
    
    print("\nConversion completed!")