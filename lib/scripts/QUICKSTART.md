# Quick Start Guide - NYC Address Lookup

## 1. Get API Credentials (One-time setup)

Visit: https://developer.cityofnewyork.us/api/geoclient-api
- Sign up / Log in
- Create new app
- Enable "Geoclient API"
- Copy your App ID and App Key

## 2. Set Environment Variables

```bash
export NYC_GEOCLIENT_APP_ID='your-app-id-here'
export NYC_GEOCLIENT_APP_KEY='your-app-key-here'
```

## 3. Put Your CSV File Here

Save your exported Google Sheets CSV to:
```
/home/user/omrails/data/addresses.csv
```

Your CSV should have these columns:
- `Organization - Street Number` (or `Street Number`)
- `Organization - Street` (or `Street`)
- `Organization - Zip Code` (can be empty for 30% of addresses)
- `City` (will be filled in)
- `State` (should already have "NY")

## 4. Run the Script

```bash
cd /home/user/omrails
ruby lib/scripts/address_lookup.rb data/addresses.csv data/addresses_complete.csv
```

## 5. Check Results

Your updated CSV will be at:
```
/home/user/omrails/data/addresses_complete.csv
```

Look for any rows marked "NEEDS REVIEW" in the `Manual Review` column.

## That's It!

For detailed documentation, see: `README_ADDRESS_LOOKUP.md`
