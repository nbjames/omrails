# NYC Address Lookup Script

This script takes a CSV file with partial NYC addresses (house number and street name) and uses the Google Maps Geocoding API to find complete mailing addresses including city and zip code.

## Prerequisites

1. **Google Maps API Key**
   - You can use your existing Google Maps API key
   - The Geocoding API must be enabled for your project

2. **Ruby** (already installed with Rails)

## Setup Instructions

### Step 1: Verify Your API Key

Your API key needs to have the **Geocoding API** enabled. To verify:

1. Go to: https://console.cloud.google.com/google/maps-apis
2. Select your project
3. Click "APIs & Services" > "Enabled APIs & services"
4. Ensure "Geocoding API" is in the list
5. If not, click "+ ENABLE APIS AND SERVICES" and search for "Geocoding API"

### Step 2: Set Environment Variable

Set your Google Maps API key as an environment variable:

```bash
export GOOGLE_MAPS_API_KEY='AIzaSyAqIXutPBphGAW5yXv6zIsYJQAvijlorKQ'
```

**Note:** This environment variable is only set for your current terminal session. To make it permanent, add it to your `~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`:

```bash
echo "export GOOGLE_MAPS_API_KEY='AIzaSyAqIXutPBphGAW5yXv6zIsYJQAvijlorKQ'" >> ~/.bashrc
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
   - Uses existing ZIP code if available (70% of your data) for more accurate geocoding
   - If no ZIP code is available, adds "New York, NY" to the search
   - Calls Google Maps Geocoding API to lookup the address
   - Verifies the result is actually in NYC (one of the 5 boroughs)
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
  ✗ Failed: Address not found
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

### "Missing API key" error
- Make sure you've set the environment variable:
  ```bash
  export GOOGLE_MAPS_API_KEY='your-api-key'
  ```
- Verify it's set with: `echo $GOOGLE_MAPS_API_KEY`

### "Address not found" errors
- Verify the house number and street name are correct
- Check for typos in the original data
- Some addresses may not exist or may be too new for Google's database
- Addresses marked for manual review will need to be verified manually

### API Errors or "REQUEST_DENIED"
- **Most Common**: If you see "API keys with referer restrictions cannot be used with this API":
  - Your API key has HTTP referer restrictions (common for web apps)
  - You need to either:
    1. Create a new API key without restrictions for server-side use, OR
    2. Remove referer restrictions from your existing key (in Google Cloud Console > Credentials)
- Ensure the Geocoding API is enabled in your Google Cloud Console
- Check that your API key is valid and hasn't expired
- Verify billing is set up (Google requires billing info even for free tier)
- Check your API usage limits in the Google Cloud Console

### API Rate Limits
- Google Maps free tier includes:
  - $200 monthly credit (approximately 40,000 geocoding requests)
  - Rate limit: 50 requests per second
- The script includes a 0.1 second delay between requests to be safe
- If you exceed limits, you may need to:
  - Process in batches
  - Upgrade your Google Cloud billing plan
  - Monitor usage at: https://console.cloud.google.com/google/maps-apis

### Wrong Column Names
If your CSV has different column names, you can either:
1. Rename your columns in Google Sheets before exporting, OR
2. Edit the script at line 185-187 to match your column names:
   ```ruby
   house_number = row['Your Column Name Here']
   street = row['Your Other Column Name']
   zip_code = row['Your ZIP Column']
   ```

### "Address found but not in New York City"
- The script validates that results are actually in NYC (5 boroughs)
- If you get this error, the address might be in:
  - Upstate New York
  - New Jersey
  - Connecticut
  - Another location with a similar street name
- Review these addresses manually to ensure they're correct

## Column Name Flexibility

The script automatically looks for common variations of column names:
- House number: `Organization - Street Number`, `Street Number`, or `House Number`
- Street: `Organization - Street`, `Street`, or `Street Name`
- ZIP Code: `Organization - Zip Code`, `Zip Code`, or `ZIP`
- City: `City`

## NYC Borough Validation

The script verifies addresses are in one of NYC's 5 boroughs:
- **Manhattan** (New York County)
- **Brooklyn** (Kings County)
- **Queens** (Queens County)
- **Bronx** (Bronx County)
- **Staten Island** (Richmond County)

Addresses outside these areas will be marked for manual review.

## After Running the Script

1. Review the output statistics
2. Check any addresses marked for "Manual Review"
3. Import the updated CSV back into Google Sheets if needed
4. Manually fix any addresses that couldn't be automatically resolved

## API Documentation

For more information about the Google Maps Geocoding API:
- Official Documentation: https://developers.google.com/maps/documentation/geocoding
- API Console: https://console.cloud.google.com/google/maps-apis
- Pricing: https://developers.google.com/maps/documentation/geocoding/usage-and-billing

## Cost Estimation

With your API key, geocoding costs:
- **First $200/month**: FREE (included credit)
- **After $200**: $5.00 per 1,000 requests

Example: If you have 500 addresses to geocode:
- Cost: $0.00 (well within free tier)

If you have 50,000 addresses:
- Cost: ~$12.50 (after free tier credit)

## Support

If you encounter issues:
1. Check that your CSV columns match the expected names
2. Verify your API key is correct and Geocoding API is enabled
3. Ensure the addresses are actually in NYC
4. Check the "Manual Review" column for specific error messages
5. Monitor API usage in Google Cloud Console
