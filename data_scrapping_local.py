import asyncio
import aiohttp
import json
import os
import time
import logging
from datetime import datetime
from pathlib import Path

# List of regions
regions = ["R001000", "R002000", "R003000", "R005000", "R006000", "R007000",
           "R008000", "R009000", "R00LAV0", "R00NIR0", "R010000", "R011000",
           "R012000", "R013000", "R04A000", "R04B000", "R0BARMM", "R0CAR00", "R0NCR00"]

# Semaphore to limit concurrent requests (adjust based on server capacity)
MAX_CONCURRENT_REQUESTS = 10

# Set up logging
def setup_logging():
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    # Create a timestamp for the log filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_dir / f"election_scraper_{timestamp}.log"
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()  # Also output to console
        ]
    )
    
    logging.info(f"Starting election data scraping at {datetime.now()}")
    return log_file

async def fetch_json(session, url, retries=3):
    """Fetch JSON data from URL with retry logic"""
    for attempt in range(retries):
        try:
            # Add small delay to be nice to the server
            await asyncio.sleep(0.1)
            
            logging.debug(f"Requesting URL: {url}")
            async with session.get(url, timeout=10) as response:
                if response.status == 404:
                    logging.warning(f"URL not found (404): {url}")
                    return None
                    
                response.raise_for_status()
                data = await response.json()
                logging.debug(f"Successfully fetched data from: {url}")
                return data
                
        except aiohttp.ClientResponseError as e:
            logging.error(f"HTTP error {e.status} on {url}: {e.message}", exc_info=(attempt == retries-1))
        except aiohttp.ClientError as e:
            logging.error(f"Request failed for {url}: {e}", exc_info=(attempt == retries-1))
        except asyncio.TimeoutError:
            logging.error(f"Request timeout for {url}", exc_info=(attempt == retries-1))
        except json.JSONDecodeError as e:
            logging.error(f"Invalid JSON from {url}: {e}", exc_info=(attempt == retries-1))
        except Exception as e:
            logging.error(f"Unexpected error accessing {url}: {e}", exc_info=(attempt == retries-1))
            
        if attempt < retries - 1:
            delay = 1 * (attempt + 1)  # Exponential backoff
            logging.info(f"Retrying {url} in {delay} seconds (attempt {attempt+1}/{retries})")
            await asyncio.sleep(delay)
        else:
            logging.error(f"Failed to fetch {url} after {retries} attempts")
            return None

async def process_precinct(session, semaphore, precinct, data_precincts, city_dir, barangay_code, barangay_name, city_name, province_name):
    """Process precinct data"""
    precinct_code = precinct['code']

    async with semaphore:
        try:
            data_number = precinct_code[:3]
            url = f"https://2025electionresults.comelec.gov.ph/data/er/{data_number}/{precinct_code}.json"
            
            logging.info(f"Fetching data for precinct {precinct_code} in {barangay_name}, {city_name}, {province_name}")
            data_votes = await fetch_json(session, url)

            if not data_votes:
                logging.warning(f"No data returned for precinct {precinct_code}")
                return

            # Validate the expected data structure
            if "information" not in data_votes or "location" not in data_votes["information"]:
                logging.warning(f"Invalid data structure for precinct {precinct_code}: missing information or location")
                return

            # Extract location and get the last part (barangay name)
            location = data_votes["information"]["location"]
            location_last_part = location.split(',')[-1].strip().lower().replace(" ", "-")

            # Create a unique identifier based on the precinct code
            precinct_specific_file = f'{city_dir}/{location_last_part}_{barangay_code}_{precinct_code}.json'

            # Check if this exact precinct has already been processed
            if os.path.exists(precinct_specific_file):
                logging.info(f"Skipping already processed precinct: {precinct_code}")
                return True

            # We'll save with a consistent naming pattern that includes the precinct code
            with open(precinct_specific_file, 'w', encoding='utf-8') as file:
                json.dump(data_votes, file, ensure_ascii=False, indent=4)

            logging.info(f"Successfully saved: {precinct_specific_file}")
            return True

        except aiohttp.ClientError as e:
            logging.error(f"Network error for precinct {precinct_code}: {e}", exc_info=True)
            return False
        except json.JSONDecodeError as e:
            logging.error(f"JSON decode error for precinct {precinct_code}: {e}", exc_info=True)
            return False
        except IOError as e:
            logging.error(f"File I/O error for precinct {precinct_code}: {e}", exc_info=True)
            return False
        except Exception as e:
            logging.error(f"Unexpected error processing precinct {precinct_code}: {e}", exc_info=True)
            return False

async def process_barangay(session, semaphore, barangay, city_dir, city_name, province_name):
    """Process barangay data"""
    barangay_code = barangay['code']
    barangay_name = barangay['name']

    logging.info(f"Processing the barangay of {barangay_name} in city of {city_name}, {province_name}")

    async with semaphore:
        try:
            precinct_number = barangay_code[:2]
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/precinct/{precinct_number}/{barangay_code}.json"
            data_precincts = await fetch_json(session, url)

            if not data_precincts:
                logging.warning(f"No precincts data for barangay {barangay_code}")
                return
                
            # Verify data structure
            if 'regions' not in data_precincts:
                logging.warning(f"Missing 'regions' key in data for barangay {barangay_code}")
                return
                
        except Exception as e:
            logging.error(f"Error fetching precincts for barangay {barangay_code}: {e}", exc_info=True)
            return

    # Process precincts concurrently
    tasks = []
    logging.info(f"Found {len(data_precincts['regions'])} precincts in barangay {barangay_name}")
    
    for precinct in data_precincts['regions']:
        task = process_precinct(
            session, semaphore, precinct, data_precincts, city_dir,
            barangay_code, barangay_name, city_name, province_name
        )
        tasks.append(task)

    if tasks:
        try:
            # Process up to 5 precincts at a time from each barangay
            chunk_size = 5
            for i in range(0, len(tasks), chunk_size):
                await asyncio.gather(*tasks[i:i+chunk_size])
            logging.info(f"Completed processing barangay {barangay_name}")
        except Exception as e:
            logging.error(f"Error during concurrent processing of precincts in {barangay_name}: {e}", exc_info=True)

async def process_city(session, semaphore, city, province_dir, province_name, region):
    """Process city data"""
    city_code = city['code']
    city_name = city['name']

    logging.info(f"Processing the city of {city_name} in {province_name} (code: {city_code})")

    try:
        # Create city directory
        city_name_folder = city_name.lower().replace(" ", "-")
        city_dir = province_dir / city_name_folder
        city_dir.mkdir(exist_ok=True)
    except Exception as e:
        logging.error(f"Error creating directory for {city_name}: {e}", exc_info=True)
        return

    async with semaphore:
        try:
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/local/{city_code}.json"
            data_barangays = await fetch_json(session, url)

            if not data_barangays:
                logging.warning(f"No barangays data for city {city_code}")
                return
                
            # Verify data structure
            if 'regions' not in data_barangays:
                logging.warning(f"Missing 'regions' key in data for city {city_code}")
                return
                
            logging.info(f"Found {len(data_barangays['regions'])} barangays in {city_name}")
            
        except Exception as e:
            logging.error(f"Error fetching barangays for city {city_code}: {e}", exc_info=True)
            return

    # Process barangays concurrently
    tasks = []
    for barangay in data_barangays['regions']:
        task = process_barangay(
            session, semaphore, barangay, city_dir, city_name, province_name
        )
        tasks.append(task)

    if tasks:
        try:
            # Process barangays in smaller groups to avoid overwhelming
            chunk_size = 3
            for i in range(0, len(tasks), chunk_size):
                await asyncio.gather(*tasks[i:i+chunk_size])
            logging.info(f"Completed processing city {city_name}")
        except Exception as e:
            logging.error(f"Error during concurrent processing of barangays in {city_name}: {e}", exc_info=True)

async def process_province(session, semaphore, province, region_dir, region):
    """Process province data"""
    province_code = province['code']
    province_name = province['name']

    logging.info(f"Processing the province of {province_name} (code: {province_code})")

    try:
        # Create province directory
        province_name_folder = province_name.lower().replace(" ", "-")
        province_dir = region_dir / province_name_folder
        province_dir.mkdir(exist_ok=True)
    except Exception as e:
        logging.error(f"Error creating directory for {province_name}: {e}", exc_info=True)
        return

    async with semaphore:
        try:
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/local/{province_code}.json"
            data_cities = await fetch_json(session, url)

            if not data_cities:
                logging.warning(f"No cities data for province {province_code}")
                return
                
            # Verify data structure
            if 'regions' not in data_cities:
                logging.warning(f"Missing 'regions' key in data for province {province_code}")
                return
                
            logging.info(f"Found {len(data_cities['regions'])} cities/municipalities in {province_name}")
            
        except Exception as e:
            logging.error(f"Error fetching cities for province {province_code}: {e}", exc_info=True)
            return

    # Process cities concurrently
    tasks = []
    for city in data_cities['regions']:
        task = process_city(
            session, semaphore, city, province_dir, province_name, region
        )
        tasks.append(task)

    if tasks:
        try:
            # Process cities in smaller groups (2 at a time) for better control
            chunk_size = 2
            for i in range(0, len(tasks), chunk_size):
                await asyncio.gather(*tasks[i:i+chunk_size])
            logging.info(f"Completed processing province {province_name}")
        except Exception as e:
            logging.error(f"Error during concurrent processing of cities in {province_name}: {e}", exc_info=True)

async def process_region(session, semaphore, region, base_dir):
    """Process region data"""
    logging.info(f"Processing region: {region}")

    try:
        # Create region directory
        region_dir = base_dir / region
        region_dir.mkdir(exist_ok=True)
    except Exception as e:
        logging.error(f"Error creating directory for region {region}: {e}", exc_info=True)
        return

    async with semaphore:
        try:
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/local/{region}.json"
            data_provinces = await fetch_json(session, url)

            if not data_provinces:
                logging.warning(f"No provinces data for region {region}")
                return
                
            # Verify data structure
            if 'regions' not in data_provinces:
                logging.warning(f"Missing 'regions' key in data for region {region}")
                return
                
            logging.info(f"Found {len(data_provinces['regions'])} provinces in region {region}")
            
        except Exception as e:
            logging.error(f"Error fetching provinces for region {region}: {e}", exc_info=True)
            return

    # Process provinces sequentially for stability
    tasks = []
    for province in data_provinces['regions']:
        task = process_province(
            session, semaphore, province, region_dir, region
        )
        tasks.append(task)

    if tasks:
        try:
            # Process one province at a time to avoid overwhelming
            for task in tasks:
                await task
            logging.info(f"Completed processing region {region}")
        except Exception as e:
            logging.error(f"Error during sequential processing of provinces in {region}: {e}", exc_info=True)

async def main():
    """Main function to run the scraper"""
    # Setup logging
    log_file = setup_logging()
    logging.info(f"Starting election data scraper. Log file: {log_file}")
    logging.info(f"Will process {len(regions)} regions with max {MAX_CONCURRENT_REQUESTS} concurrent requests")
    
    BASE_DIR = Path("election_data")
    BASE_DIR.mkdir(exist_ok=True)

    # Create semaphore to limit concurrent requests
    semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)

    try:
        # Using ClientSession for connection pooling and cookie persistence
        connector = aiohttp.TCPConnector(limit=MAX_CONCURRENT_REQUESTS)
        async with aiohttp.ClientSession(connector=connector) as session:
            # Process regions one at a time for stability
            for region in regions:
                await process_region(session, semaphore, region, BASE_DIR)
                
        logging.info("Election data scraping completed successfully")
    except Exception as e:
        logging.critical(f"Critical error in main function: {e}", exc_info=True)
    finally:
        logging.info(f"Election data scraping process ended at {datetime.now()}")

if __name__ == "__main__":
    start_time = time.time()
    asyncio.run(main())
    end_time = time.time()
    total_time = end_time - start_time
    print(f"Total execution time: {total_time:.2f} seconds ({total_time/60:.2f} minutes)")