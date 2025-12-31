#!/usr/bin/env ruby
#
# NYC Address Lookup Script using Google Maps Geocoding API
#
# This script takes a CSV file with partial NYC addresses (house number and street name)
# and uses the Google Maps Geocoding API to find complete mailing addresses including city and zip code.
#
# Usage:
#   ruby lib/scripts/address_lookup.rb input.csv output.csv
#

require 'csv'
require 'net/http'
require 'json'
require 'uri'

class GoogleMapsAddressLookup
  API_BASE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'

  def initialize(api_key)
    @api_key = api_key
  end

  def lookup_address(house_number, street, zip_code = nil)
    return nil if house_number.nil? || house_number.to_s.strip.empty?
    return nil if street.nil? || street.to_s.strip.empty?

    # Build the full address string for Google Maps
    address_parts = ["#{house_number} #{street}"]

    # Add zip code if available for more accurate results
    if zip_code && !zip_code.to_s.strip.empty?
      address_parts << zip_code
    else
      # Specify New York, NY to limit search to NYC
      address_parts << "New York, NY"
    end

    address = address_parts.join(', ')

    make_request(address)
  end

  private

  def make_request(address)
    # Build API request
    params = {
      'address' => address,
      'key' => @api_key
    }

    uri = URI(API_BASE_URL)
    uri.query = URI.encode_www_form(params)

    begin
      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        data = JSON.parse(response.body)

        if data['status'] == 'OK' && data['results'] && data['results'].size > 0
          result = data['results'][0]

          # Extract address components
          components = extract_address_components(result['address_components'])

          # Verify this is actually in New York City
          unless is_nyc_address?(components)
            return { success: false, error: 'Address found but not in New York City' }
          end

          {
            success: true,
            city: components[:city] || 'New York',
            zip_code: components[:zip_code],
            state: components[:state] || 'NY',
            county: components[:county],
            formatted_address: result['formatted_address'],
            location: result['geometry']['location']
          }
        elsif data['status'] == 'ZERO_RESULTS'
          { success: false, error: 'Address not found' }
        else
          { success: false, error: "API Error: #{data['status']} - #{data['error_message']}" }
        end
      else
        { success: false, error: "HTTP Error: #{response.code} - #{response.message}" }
      end
    rescue StandardError => e
      { success: false, error: "Request failed: #{e.message}" }
    end
  end

  def extract_address_components(components)
    result = {}

    components.each do |component|
      types = component['types']

      if types.include?('locality')
        result[:city] = component['long_name']
      elsif types.include?('postal_code')
        result[:zip_code] = component['long_name']
      elsif types.include?('administrative_area_level_1')
        result[:state] = component['short_name']
      elsif types.include?('administrative_area_level_2')
        result[:county] = component['long_name']
      end
    end

    result
  end

  def is_nyc_address?(components)
    # Check if the address is in one of NYC's 5 boroughs (counties)
    nyc_counties = ['New York County', 'Kings County', 'Queens County', 'Bronx County', 'Richmond County']

    return true if components[:county] && nyc_counties.include?(components[:county])

    # Also check if state is NY and city is New York (covers most cases)
    return true if components[:state] == 'NY' && components[:city] == 'New York'

    # For outer boroughs that might have different city names
    nyc_cities = ['New York', 'Brooklyn', 'Bronx', 'Queens', 'Staten Island']
    return true if components[:state] == 'NY' && nyc_cities.include?(components[:city])

    false
  end
end

class CSVAddressProcessor
  def initialize(input_file, output_file, api_key)
    @input_file = input_file
    @output_file = output_file
    @lookup = GoogleMapsAddressLookup.new(api_key)
    @stats = {
      total: 0,
      updated: 0,
      already_complete: 0,
      failed: 0
    }
  end

  def process
    unless File.exist?(@input_file)
      puts "Error: Input file '#{@input_file}' not found"
      return
    end

    puts "Reading CSV file: #{@input_file}"
    puts "=" * 60

    # Read CSV with headers
    csv_data = CSV.read(@input_file, headers: true)

    # Process each row
    csv_data.each_with_index do |row, index|
      @stats[:total] += 1

      # Display progress
      puts "\nProcessing row #{index + 1} of #{csv_data.size}..."

      process_row(row)

      # Add a small delay to avoid hitting API rate limits
      sleep(0.1) if index < csv_data.size - 1
    end

    # Write updated CSV
    puts "\n" + "=" * 60
    puts "Writing results to: #{@output_file}"
    CSV.open(@output_file, 'w', write_headers: true, headers: csv_data.headers) do |csv|
      csv_data.each { |row| csv << row }
    end

    # Print statistics
    print_stats
  end

  private

  def process_row(row)
    # Get house number and street name - adjust these column names as needed
    house_number = row['Organization - Street Number'] || row['Street Number'] || row['House Number']
    street = row['Organization - Street'] || row['Street'] || row['Street Name']
    zip_code = row['Organization - Zip Code'] || row['Zip Code'] || row['ZIP']
    city = row['City']

    # Display current data
    puts "  Address: #{house_number} #{street}"
    puts "  Current ZIP: #{zip_code || '(none)'}"
    puts "  Current City: #{city || '(none)'}"

    # Check if already complete
    if city_complete?(city) && zip_complete?(zip_code)
      puts "  ✓ Address already complete - skipping"
      @stats[:already_complete] += 1
      return
    end

    # Lookup address
    puts "  Looking up address..."
    result = @lookup.lookup_address(house_number, street, zip_code)

    if result && result[:success]
      # Update city if needed
      if !city_complete?(city)
        row['City'] = result[:city]
        puts "  ✓ Added city: #{result[:city]}"
      end

      # Update zip code if needed
      if !zip_complete?(zip_code)
        row['Organization - Zip Code'] = result[:zip_code]
        puts "  ✓ Added ZIP code: #{result[:zip_code]}"
      end

      @stats[:updated] += 1
    else
      # Mark for manual review
      error_msg = result ? result[:error] : 'Unknown error'
      row['Manual Review'] = "NEEDS REVIEW: #{error_msg}"
      puts "  ✗ Failed: #{error_msg}"
      puts "  → Marked for manual review"
      @stats[:failed] += 1
    end
  end

  def city_complete?(city)
    city && !city.to_s.strip.empty?
  end

  def zip_complete?(zip)
    zip && !zip.to_s.strip.empty?
  end

  def print_stats
    puts "\n" + "=" * 60
    puts "PROCESSING COMPLETE"
    puts "=" * 60
    puts "Total addresses processed: #{@stats[:total]}"
    puts "Successfully updated: #{@stats[:updated]}"
    puts "Already complete: #{@stats[:already_complete]}"
    puts "Failed (marked for review): #{@stats[:failed]}"
    puts "=" * 60

    if @stats[:failed] > 0
      puts "\n⚠ #{@stats[:failed]} address(es) need manual review."
      puts "Check the 'Manual Review' column in the output file."
    end
  end
end

# Main execution
if __FILE__ == $0
  # Check command line arguments
  if ARGV.size < 2
    puts "Usage: ruby #{$0} input.csv output.csv"
    puts "\nEnvironment variable required:"
    puts "  GOOGLE_MAPS_API_KEY - Your Google Maps API Key"
    puts "\nGet your API key at: https://console.cloud.google.com/google/maps-apis"
    exit 1
  end

  input_file = ARGV[0]
  output_file = ARGV[1]

  # Get API key from environment variable
  api_key = ENV['GOOGLE_MAPS_API_KEY']

  unless api_key
    puts "Error: Missing API key"
    puts "\nPlease set the following environment variable:"
    puts "  export GOOGLE_MAPS_API_KEY='your-api-key'"
    puts "\nGet your API key at: https://console.cloud.google.com/google/maps-apis"
    exit 1
  end

  # Process the CSV
  processor = CSVAddressProcessor.new(input_file, output_file, api_key)
  processor.process
end
