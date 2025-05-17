import asyncio
import aiohttp
import json
import os
import time
import logging
from datetime import datetime
from pathlib import Path

# Semaphore to limit concurrent requests (adjust based on server capacity)
MAX_CONCURRENT_REQUESTS = 10

# Set up logging
def setup_logging():
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)
    
    # Create a timestamp for the log filename
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_dir / f"overseas_election_scraper_{timestamp}.log"
    
    # Configure logging
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler()  # Also output to console
        ]
    )
    
    logging.info(f"Starting overseas election data scraping at {datetime.now()}")
    return log_file

async def fetch_json(session, url, retries=3):
    """Fetch JSON data from URL with retry logic"""
    for attempt in range(retries):
        try:
            # Add small delay to be nice to the server
            await asyncio.sleep(0.1)
            async with session.get(url, timeout=10) as response:
                response.raise_for_status()
                return await response.json()
        except aiohttp.ClientResponseError as e:
            logging.error(f"HTTP error {e.status} on {url}: {e.message}", exc_info=(attempt == retries-1))
        except aiohttp.ClientError as e:
            logging.error(f"Request failed for {url}: {e}", exc_info=(attempt == retries-1))
        except asyncio.TimeoutError:
            logging.error(f"Request timeout for {url}", exc_info=(attempt == retries-1))
        except Exception as e:
            logging.error(f"Unexpected error accessing {url}: {e}", exc_info=(attempt == retries-1))
            
        if attempt < retries - 1:
            delay = 1 * (attempt + 1)  # Exponential backoff
            logging.info(f"Retrying {url} in {delay} seconds (attempt {attempt+1}/{retries})")
            await asyncio.sleep(delay)
        else:
            logging.error(f"Failed to fetch {url} after {retries} attempts")
            return None

async def process_precinct(session, semaphore, precinct, data_precincts, city_dir, jurisdiction_code, jurisdiction_name, city_name, province_name):
    """Process precinct data"""
    precinct_code = precinct['code']

    async with semaphore:
        try:
            data_number = precinct_code[:3]
            url = f"https://2025electionresults.comelec.gov.ph/data/er/{data_number}/{precinct_code}.json"
            
            logging.info(f"Fetching data for precinct {precinct_code} in {jurisdiction_name}, {city_name}, {province_name}")
            data_votes = await fetch_json(session, url)

            if not data_votes:
                logging.warning(f"No data returned for precinct {precinct_code}")
                return

            # Validate the expected data structure
            if "information" not in data_votes or "location" not in data_votes["information"]:
                logging.warning(f"Invalid data structure for precinct {precinct_code}: missing information or location")
                return

            # Extract location and get the last part (jurisdiction name)
            location = data_votes["information"]["location"]
            location_last_part = location.split(',')[-1].strip().lower().replace(" ", "-")

            # Create a unique identifier based on the precinct code
            precinct_specific_file = f'{city_dir}/{location_last_part}_{jurisdiction_code}_{precinct_code}.json'

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
            # Network-related errors
            logging.error(f"Network error for precinct {precinct_code}: {e}", exc_info=True)
            return False
        except json.JSONDecodeError as e:
            # JSON parsing errors
            logging.error(f"JSON decode error for precinct {precinct_code}: {e}", exc_info=True)
            return False
        except IOError as e:
            # File I/O errors
            logging.error(f"File I/O error for precinct {precinct_code}: {e}", exc_info=True)
            return False
        except Exception as e:
            # Catch-all for other errors
            logging.error(f"Unexpected error processing precinct {precinct_code}: {e}", exc_info=True)
            return False

async def process_jurisdiction(session, semaphore, jurisdiction, city_dir, city_name, province_name):
    """Process jurisdiction data"""
    jurisdiction_code = jurisdiction['code']
    jurisdiction_name = jurisdiction['name']

    logging.info(f"Processing the jurisdiction of {jurisdiction_name} in {city_name}, {province_name}")

    async with semaphore:
        try:
            precinct_number = jurisdiction_code[:2]
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/precinct/{precinct_number}/{jurisdiction_code}.json"
            data_precincts = await fetch_json(session, url)

            if not data_precincts:
                logging.warning(f"No precincts data for jurisdiction {jurisdiction_code}")
                return
        except Exception as e:
            logging.error(f"Error fetching precincts for jurisdiction {jurisdiction_code}: {e}", exc_info=True)
            return

    # Process precincts concurrently
    tasks = []
    for precinct in data_precincts['regions']:
        task = process_precinct(
            session, semaphore, precinct, data_precincts, city_dir,
            jurisdiction_code, jurisdiction_name, city_name, province_name
        )
        tasks.append(task)

    if tasks:
        try:
            # Process up to 5 precincts at a time from each jurisdiction
            chunk_size = 5
            for i in range(0, len(tasks), chunk_size):
                await asyncio.gather(*tasks[i:i+chunk_size])
            logging.info(f"Completed processing jurisdiction {jurisdiction_name}")
        except Exception as e:
            logging.error(f"Error during concurrent processing of precincts in {jurisdiction_name}: {e}", exc_info=True)

async def process_country_post(session, semaphore, country_post, regional_grouping_dir, regional_grouping_name, overseas):
    """Process country post data"""
    country_post_code = country_post['code']
    country_post_name = country_post['name']

    logging.info(f"Processing the country post of {country_post_name} in {regional_grouping_name}")

    try:
        # Create country_post directory
        country_post_name_folder = country_post_name.lower().replace(" ", "-")
        country_post_dir = regional_grouping_dir / country_post_name_folder
        country_post_dir.mkdir(exist_ok=True)
    except Exception as e:
        logging.error(f"Error creating directory for {country_post_name}: {e}", exc_info=True)
        return

    async with semaphore:
        try:
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/overseas/{country_post_code}.json"
            data_jurisdictions = await fetch_json(session, url)

            if not data_jurisdictions:
                logging.warning(f"No jurisdictions data for country post {country_post_code}")
                return
        except Exception as e:
            logging.error(f"Error fetching jurisdictions for country post {country_post_code}: {e}", exc_info=True)
            return

    # Process jurisdictions concurrently
    tasks = []
    for jurisdiction in data_jurisdictions['regions']:
        task = process_jurisdiction(
            session, semaphore, jurisdiction, country_post_dir, country_post_name, regional_grouping_name
        )
        tasks.append(task)

    if tasks:
        try:
            # Process jurisdictions in smaller groups to avoid overwhelming
            chunk_size = 3
            for i in range(0, len(tasks), chunk_size):
                await asyncio.gather(*tasks[i:i+chunk_size])
            logging.info(f"Completed processing country post {country_post_name}")
        except Exception as e:
            logging.error(f"Error during concurrent processing of jurisdictions in {country_post_name}: {e}", exc_info=True)

async def process_regional_grouping(session, semaphore, regional_grouping, region_dir, region):
    """Process regional grouping data"""
    regional_grouping_code = regional_grouping['code']
    regional_grouping_name = regional_grouping['name']

    logging.info(f"Processing the regional grouping of {regional_grouping_name}")

    try:
        # Create regional_grouping directory
        regional_grouping_name_folder = regional_grouping_name.lower().replace(" ", "-")
        regional_grouping_dir = region_dir / regional_grouping_name_folder
        regional_grouping_dir.mkdir(exist_ok=True)
    except Exception as e:
        logging.error(f"Error creating directory for {regional_grouping_name}: {e}", exc_info=True)
        return

    async with semaphore:
        try:
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/overseas/{regional_grouping_code}.json"
            data_countries_posts = await fetch_json(session, url)

            if not data_countries_posts:
                logging.warning(f"No country posts data for regional grouping {regional_grouping_code}")
                return
        except Exception as e:
            logging.error(f"Error fetching country posts for regional grouping {regional_grouping_code}: {e}", exc_info=True)
            return

    # Process country posts concurrently
    tasks = []
    for country_post in data_countries_posts['regions']:
        task = process_country_post(
            session, semaphore, country_post, regional_grouping_dir, regional_grouping_name, region
        )
        tasks.append(task)

    if tasks:
        try:
            # Process country posts in smaller groups for better control
            chunk_size = 2
            for i in range(0, len(tasks), chunk_size):
                await asyncio.gather(*tasks[i:i+chunk_size])
            logging.info(f"Completed processing regional grouping {regional_grouping_name}")
        except Exception as e:
            logging.error(f"Error during concurrent processing of country posts in {regional_grouping_name}: {e}", exc_info=True)

async def process_overseas(session, semaphore, overseas, base_dir):
    """Process overseas data"""
    logging.info(f"Processing overseas region: {overseas}")

    try:
        # Create region directory
        overseas_dir = base_dir / overseas
        overseas_dir.mkdir(exist_ok=True)
    except Exception as e:
        logging.error(f"Error creating directory for overseas {overseas}: {e}", exc_info=True)
        return

    async with semaphore:
        try:
            url = f"https://2025electionresults.comelec.gov.ph/data/regions/overseas/{overseas}.json"
            data_regional_groupings = await fetch_json(session, url)

            if not data_regional_groupings:
                logging.warning(f"No regional groupings data for overseas {overseas}")
                return
        except Exception as e:
            logging.error(f"Error fetching regional groupings for overseas {overseas}: {e}", exc_info=True)
            return

    # Process regional groupings sequentially for stability
    tasks = []
    for regional_grouping in data_regional_groupings['regions']:
        task = process_regional_grouping(
            session, semaphore, regional_grouping, overseas_dir, overseas
        )
        tasks.append(task)

    if tasks:
        try:
            # Process one regional grouping at a time to avoid overwhelming
            for task in tasks:
                await task
            logging.info(f"Completed processing overseas {overseas}")
        except Exception as e:
            logging.error(f"Error during sequential processing of regional groupings in {overseas}: {e}", exc_info=True)

async def main():
    """Main function to run the scraper"""
    # Setup logging
    log_file = setup_logging()
    logging.info(f"Starting overseas election data scraper. Log file: {log_file}")
    
    BASE_DIR = Path("election_data_overseas")
    BASE_DIR.mkdir(exist_ok=True)

    # Create semaphore to limit concurrent requests
    semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)

    try:
        # Using ClientSession for connection pooling and cookie persistence
        async with aiohttp.ClientSession() as session:
            # Process overseas
            overseas = "R0OAV00"
            await process_overseas(session, semaphore, overseas, BASE_DIR)
            
        logging.info("Overseas election data scraping completed successfully")
    except Exception as e:
        logging.critical(f"Critical error in main function: {e}", exc_info=True)
    finally:
        logging.info(f"Overseas election data scraping process ended at {datetime.now()}")

if __name__ == "__main__":
    start_time = time.time()
    asyncio.run(main())
    end_time = time.time()
    total_time = end_time - start_time
    print(f"Total execution time: {total_time:.2f} seconds ({total_time/60:.2f} minutes)")