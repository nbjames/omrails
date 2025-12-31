# NYC Address Lookup Script

This script takes a CSV file with partial NYC addresses (house number and street name) and uses the NYC GeoClient API to find complete mailing addresses including city and zip code.

## Prerequisites

1. **NYC GeoClient API Credentials** (Free)
   - Visit: https://developer.cityofnewyork.us/api/geoclient-api
   - Create an account or log in
   - Register a new application
   - Check off access to the "Geoclient API"
   - Note your `App ID` and `App Key`

2. **Ruby** (already installed with Rails)

## Setup Instructions

### Step 1: Get API Credentials

1. Go to https://developer.cityofnewyork.us/api/geoclient-api
2. Sign up or log in
3. Click "Create New App" or manage existing app
4. Enable "Geoclient API" access
5. Copy your `App ID` and `App Key`

### Step 2: Set Environment Variables

Open your terminal and set your API credentials as environment variables:

```bash
export NYC_GEOCLIENT_APP_ID='your-app-id-here'
export NYC_GEOCLIENT_APP_KEY='your-app-key-here'
```

**Note:** These environment variables are only set for your current terminal session. To make them permanent, add them to your `~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`:

```bash
echo "export NYC_GEOCLIENT_APP_ID='your-app-id-here'" >> ~/.bashrc
echo "export NYC_GEOCLIENT_APP_KEY='your-app-key-here'" >> ~/.bashrc
source ~/.bashrc
```

### Step 3: Prepare Your CSV File

1. Export your Google Sheet as CSV
2. Save it to the project directory, for example: `/home/user/omrails/data/addresses.csv`

#### Expected CSV Columns

The script looks for these column names (case-sensitive):
- `Organization - Street Number` or `Street Number` or `House Number` - The house/building number
- `Organization - Street` or `Street` or `Street Name` - The street name
- `Organization - Zip Code` or `Zip Code` or `ZIP` - Existing ZIP code (optional)
- `City` - Will be populated with city name if empty
- `State` - Should already be filled (not modified by script)

**Example CSV structure:**
```csv
Organization - Street Number,Organization - Street,Organization - Zip Code,City,State
123,Broadway,10012,,NY
456,5th Avenue,,New York,NY
789,Amsterdam Ave,10025,,NY
```

### Step 4: Create Data Directory (Optional)

```bash
mkdir -p /home/user/omrails/data
```

## Usage

### Basic Command

```bash
ruby lib/scripts/address_lookup.rb input.csv output.csv
```

### Example

```bash
# Process addresses from data/input.csv and save results to data/output.csv
ruby lib/scripts/address_lookup.rb data/addresses.csv data/addresses_updated.csv
```

### Full Working Example

1. Put your CSV file here:
   ```bash
   /home/user/omrails/data/addresses.csv
   ```

2. Run the script:
   ```bash
   cd /home/user/omrails
   ruby lib/scripts/address_lookup.rb data/addresses.csv data/addresses_complete.csv
   ```

3. Check the results:
   ```bash
   cat data/addresses_complete.csv
   ```

## What the Script Does

1. **Reads your CSV file** with partial address information
2. **For each row:**
   - Takes the house number and street name
   - Uses existing ZIP code if available (70% of your data)
   - Calls NYC GeoClient API to lookup the address
   - If no ZIP code is available, tries all NYC boroughs to find the address
3. **Updates the CSV:**
   - Adds city name to the `City` column (typically "New York")
   - Adds ZIP code to the `Organization - Zip Code` column if missing
4. **Error Handling:**
   - Addresses that can't be found are marked in a new `Manual Review` column
   - The script continues processing even if some addresses fail
5. **Outputs statistics** showing how many addresses were updated, skipped, or need review

## Sample Output

```
Reading CSV file: data/addresses.csv
============================================================

Processing row 1 of 10...
  Address: 123 Broadway
  Current ZIP: 10012
  Current City: (none)
  Looking up address...
  ✓ Added city: New York

Processing row 2 of 10...
  Address: 456 5th Avenue
  Current ZIP: (none)
  Current City: New York
  Looking up address...
  ✓ Added ZIP code: 10016

Processing row 3 of 10...
  Address: 999 Fake Street
  Current ZIP: (none)
  Current City: (none)
  Looking up address...
  ✗ Failed: Address not found in any NYC borough
  → Marked for manual review

============================================================
Writing results to: data/addresses_complete.csv
============================================================
PROCESSING COMPLETE
============================================================
Total addresses processed: 10
Successfully updated: 8
Already complete: 1
Failed (marked for review): 1
============================================================

⚠ 1 address(es) need manual review.
Check the 'Manual Review' column in the output file.
```

## Troubleshooting

### "Missing API credentials" error
- Make sure you've set the environment variables:
  ```bash
  export NYC_GEOCLIENT_APP_ID='your-app-id'
  export NYC_GEOCLIENT_APP_KEY='your-app-key'
  ```
- Verify they're set with: `echo $NYC_GEOCLIENT_APP_ID`

### "Address not found" errors
- Verify the house number and street name are correct
- Check for typos in the original data
- Some addresses may not exist in NYC's database
- Addresses marked for manual review will need to be verified manually

### API Rate Limits
- The free NYC GeoClient API has rate limits
- If you have a very large CSV (1000+ addresses), you may need to:
  - Process in batches
  - Add delays between requests (script can be modified)
  - Contact NYC for higher rate limits

### Wrong Column Names
If your CSV has different column names, you can either:
1. Rename your columns in Google Sheets before exporting, OR
2. Edit the script at line 135-137 to match your column names:
   ```ruby
   house_number = row['Your Column Name Here']
   street = row['Your Other Column Name']
   zip_code = row['Your ZIP Column']
   ```

## Column Name Flexibility

The script automatically looks for common variations of column names:
- House number: `Organization - Street Number`, `Street Number`, or `House Number`
- Street: `Organization - Street`, `Street`, or `Street Name`
- ZIP Code: `Organization - Zip Code`, `Zip Code`, or `ZIP`
- City: `City`

## After Running the Script

1. Review the output statistics
2. Check any addresses marked for "Manual Review"
3. Import the updated CSV back into Google Sheets if needed
4. Manually fix any addresses that couldn't be automatically resolved

## API Documentation

For more information about the NYC GeoClient API:
- Official Documentation: https://maps.nyc.gov/geoclient/v1/doc
- Developer Portal: https://developer.cityofnewyork.us/api/geoclient-api

## Support

If you encounter issues:
1. Check that your CSV columns match the expected names
2. Verify your API credentials are correct
3. Ensure the addresses are actually in NYC
4. Check the "Manual Review" column for specific error messages
