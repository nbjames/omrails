#!/usr/bin/env ruby
#
# NYC Address Lookup Script
#
# This script takes a CSV file with partial NYC addresses (house number and street name)
# and uses the NYC GeoClient API to find complete mailing addresses including city and zip code.
#
# Usage:
#   ruby lib/scripts/address_lookup.rb input.csv output.csv
#

require 'csv'
require 'net/http'
require 'json'
require 'uri'

class NYCAddressLookup
  API_BASE_URL = 'https://api.nyc.gov/geo/geoclient/v1'

  # NYC boroughs for lookup
  BOROUGHS = ['Manhattan', 'Bronx', 'Brooklyn', 'Queens', 'Staten Island']

  def initialize(app_id, app_key)
    @app_id = app_id
    @app_key = app_key
  end

  def lookup_address(house_number, street, zip_code = nil, borough = nil)
    return nil if house_number.nil? || house_number.to_s.strip.empty?
    return nil if street.nil? || street.to_s.strip.empty?

    # Build API request parameters
    params = {
      'houseNumber' => house_number.to_s.strip,
      'street' => street.to_s.strip,
      'app_id' => @app_id,
      'app_key' => @app_key
    }

    # Add zip or borough (prefer zip if available)
    if zip_code && !zip_code.to_s.strip.empty?
      params['zip'] = zip_code.to_s.strip
    elsif borough && !borough.to_s.strip.empty?
      params['borough'] = borough
    else
      # If no zip or borough provided, try each NYC borough
      return try_all_boroughs(house_number, street)
    end

    make_request(params)
  end

  private

  def try_all_boroughs(house_number, street)
    # Try each borough until we get a valid response
    BOROUGHS.each do |borough|
      params = {
        'houseNumber' => house_number.to_s.strip,
        'street' => street.to_s.strip,
        'borough' => borough,
        'app_id' => @app_id,
        'app_key' => @app_key
      }

      result = make_request(params)
      return result if result && result[:success]
    end

    # No borough matched
    { success: false, error: 'Address not found in any NYC borough' }
  end

  def make_request(params)
    uri = URI("#{API_BASE_URL}/address.json")
    uri.query = URI.encode_www_form(params)

    begin
      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        data = JSON.parse(response.body)

        if data['address']
          # Extract relevant information
          address_data = data['address']
          {
            success: true,
            city: address_data['cityStateZipCode']&.split(',')&.first&.strip || 'New York',
            zip_code: address_data['zipCode'] || address_data['zip5'],
            borough: address_data['borough'],
            full_address: "#{address_data['houseNumber']} #{address_data['firstStreetNameNormalized']}",
            bbl: address_data['bbl'],
            bin: address_data['buildingIdentificationNumber']
          }
        else
          { success: false, error: data['message'] || 'Address not found' }
        end
      else
        { success: false, error: "API Error: #{response.code} - #{response.message}" }
      end
    rescue StandardError => e
      { success: false, error: "Request failed: #{e.message}" }
    end
  end
end

class CSVAddressProcessor
  def initialize(input_file, output_file, app_id, app_key)
    @input_file = input_file
    @output_file = output_file
    @lookup = NYCAddressLookup.new(app_id, app_key)
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
    puts "\nEnvironment variables required:"
    puts "  NYC_GEOCLIENT_APP_ID  - Your NYC GeoClient App ID"
    puts "  NYC_GEOCLIENT_APP_KEY - Your NYC GeoClient App Key"
    puts "\nGet your API credentials at: https://developer.cityofnewyork.us/api/geoclient-api"
    exit 1
  end

  input_file = ARGV[0]
  output_file = ARGV[1]

  # Get API credentials from environment variables
  app_id = ENV['NYC_GEOCLIENT_APP_ID']
  app_key = ENV['NYC_GEOCLIENT_APP_KEY']

  unless app_id && app_key
    puts "Error: Missing API credentials"
    puts "\nPlease set the following environment variables:"
    puts "  export NYC_GEOCLIENT_APP_ID='your-app-id'"
    puts "  export NYC_GEOCLIENT_APP_KEY='your-app-key'"
    puts "\nGet your API credentials at: https://developer.cityofnewyork.us/api/geoclient-api"
    exit 1
  end

  # Process the CSV
  processor = CSVAddressProcessor.new(input_file, output_file, app_id, app_key)
  processor.process
end
