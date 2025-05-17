# 2025 COMELEC National and Local Election Data Scraper

A comprehensive tool for collecting, organizing, and analyzing election data from the 2025 Philippines Commission on Elections (COMELEC) national and local elections.

## Overview

This repository contains Python scripts to efficiently scrape and organize election data from the COMELEC website. It uses asynchronous programming to quickly retrieve large amounts of data from different geographic levels (regions, provinces, cities/municipalities, barangays, and precincts) and stores them in a structured file system for further analysis.

## Features

- **Asynchronous Data Collection**: Uses `asyncio` and `aiohttp` for fast, concurrent data retrieval
- **Complete Geographic Coverage**: Scrapes data from all regions in the Philippines
- **Overseas Voting Support**: Includes specialized code for overseas voting data
- **Deduplication System**: Prevents duplicate data while allowing for updates
- **Comprehensive Logging**: Detailed logs for monitoring and debugging
- **Error Handling**: Robust error recovery mechanisms
- **Efficient Resource Usage**: Throttles requests to respect server limitations

## Directory Structure

The scraped data is organized in a hierarchical structure:

```
election_data/
├── R001000/
│   ├── ilocos-norte/
│   │   ├── laoag-city/
│   │   │   ├── barangay_1_code_precinct_code.json
│   │   │   └── ...
│   │   └── ...
│   └── ...
├── R002000/
└── ...

election_data_overseas/
├── R0OAV00/
    ├── asia/
    │   ├── tokyo-japan/
    │   │   ├── jurisdiction_code_precinct_code.json
    │   │   └── ...
    │   └── ...
    └── ...
```

## Requirements

- Python 3.8+
- aiohttp
- asyncio
- Other dependencies listed in `requirements.txt`

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/cancinoray/2025-comelec-national-and-local-election.git
   cd 2025-comelec-national-and-local-election
   ```

2. Create and activate a virtual environment:
   ```bash
   python -m venv env
   source env/bin/activate  # On Windows: env\Scripts\activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Scraping Local Election Data

```bash
python data_scraping_local.py
```

This will scrape data from all regions and save it to the `election_data` directory.

### Scraping Overseas Voting Data

```bash
python data_scraping_overseas.py
```

This will scrape overseas voting data and save it to the `election_data_overseas` directory.

### Configuration

You can adjust the following parameters in the scripts:

- `MAX_CONCURRENT_REQUESTS`: Controls the maximum number of concurrent HTTP requests
- `regions`: List of region codes to scrape from

## Logs

Logs are saved in the `logs` directory with timestamps. They contain detailed information about:

- Successful data retrievals and saves
- HTTP errors and retries
- Data structure validation
- Processing times

## Data Analysis

After scraping the data, you can use the collected JSON files for various analyses:

- Election results visualization
- Geographic distribution of votes
- Turnout statistics
- Candidate performance analysis

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## Acknowledgments

- COMELEC for providing the election data

## Disclaimer

This tool is for educational and research purposes only. Make sure to respect COMELEC's terms of service and rate limits when using this scraper.