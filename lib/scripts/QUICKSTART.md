# Quick Start Guide - NYC Address Lookup

## 1. Set Your API Key

You already have a Google Maps API key! Just set it as an environment variable:

```bash
export GOOGLE_MAPS_API_KEY='AIzaSyAqIXutPBphGAW5yXv6zIsYJQAvijlorKQ'
```

**Make it permanent** (optional):
```bash
echo "export GOOGLE_MAPS_API_KEY='AIzaSyAqIXutPBphGAW5yXv6zIsYJQAvijlorKQ'" >> ~/.bashrc
source ~/.bashrc
```

## 2. Put Your CSV File Here

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

## 3. Run the Script

```bash
cd /home/user/omrails
ruby lib/scripts/address_lookup.rb data/addresses.csv data/addresses_complete.csv
```

## 4. Check Results

Your updated CSV will be at:
```
/home/user/omrails/data/addresses_complete.csv
```

Look for any rows marked "NEEDS REVIEW" in the `Manual Review` column.

## That's It!

For detailed documentation, see: `README_ADDRESS_LOOKUP.md`

## Troubleshooting

**If you get "API keys with referer restrictions" error:**
- Your API key has HTTP referer restrictions (for web apps)
- Create a new unrestricted API key OR remove restrictions in Google Cloud Console > Credentials

**If you get other API errors:**
- Ensure Geocoding API is enabled at: https://console.cloud.google.com/google/maps-apis
- Verify billing is set up (required even for free tier)

**The script will:**
- ✓ Fill in missing city names (usually "New York")
- ✓ Fill in missing ZIP codes
- ✓ Validate addresses are actually in NYC
- ✓ Mark problematic addresses for manual review
- ✓ Show progress and statistics
