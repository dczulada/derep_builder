require 'rack'
require 'byebug'
require 'cqm-parsers'
require './lib/data_criteria_attribute_builder.rb'
require_relative "config/environment"

class Application
  def call(env)
    # Measure info includes the measures CMS_ID, category, and whether its an episode of care
    measure_info_file = File.new File.join('config/measure-info.json')
    measure_info = JSON.parse(measure_info_file.read)

    # This sdc list code is just a way to verify and display that the measures are being parsed correctly, it can be removed
    sdc_list = []

    # The export_to_drupal.rb starts with getting all valuesets and measures from the database
    # This rackapp can run without mongo, so the measures and valuesets will be stored in memory after parsing the measure specs
    valuesets = []
    measures = []

    # iterate through each measure spec in the measures folder
    Dir.glob('measures/*.zip') do |measure_filename|
      # use cqm-parsers to extract a measure object from the zip file
      measure_file = File.new File.join(measure_filename)
      cms_id = measure_filename.gsub('-', '')[%r{measures/(.*?)v}m, 1]
      # sometimes the connection with vsac can break, try a few times
      begin
        retries ||= 0
        puts cms_id
        measure_details = { 'episode_of_care' => measure_info[cms_id]['episode_of_care'] }
        # get a value_set_loader each time to avoid having the ticket_granting_ticket time out
        loader = Measures::CqlLoader.new(measure_file, measure_details, get_value_set_loader)
        # will return an array of CQMMeasures, most of the time there will only be a single measure
        # if the measure is a composite measure, the array will contain the composite and all of the components
        extracted_measures = loader.extract_measures
        measure = extracted_measures.first
      rescue
        retry if (retries += 1) < 3
      end


      # Use the DataCriteriaAttributeBuilder to find attributes related to each Data Criteria
      dcab = DataCriteriaAttributeBuilder.new
      dcab.build_data_criteria_for_measure(measure, measure.value_sets)

      # This sdc list code is just a way to verify and display that the measures are being parsed correctly, it can be removed
      sdc_list << "<li>#{cms_id}</li><ul>"
      measure.source_data_criteria.each do |sdc|
        sdc_list << "<li>#{sdc.description}</li>"
        if !sdc['dataElementAttributes'].nil?
          sdc_list << "<ul>"
          sdc['dataElementAttributes'].each do |dea|
            if dea[:attribute_valueset]
              sdc_list << "<li>#{dea[:attribute_name]} - #{dea[:attribute_valueset]}</li>"
            else
              sdc_list << "<li>#{dea[:attribute_name]}</li>"
            end
          end
          sdc_list << "</ul>"
        end
      end
      sdc_list << "</ul>"

      # Add the current measure and valuesets to appropriate arrays
      measures << measure
      valuesets.concat(measure.value_sets)
    end

    status  = 200
    headers = { "content-type" => "text/html" } 
    body    = ["<html><body><h1><ul>#{sdc_list.join}</ul></h1></body></html>"]
    [status, headers, body]
  end

  def get_value_set_loader
    vsac_options = { profile: APP_CONFIG['vsac']['default_profile'] }
    value_set_loader = Measures::VSACValueSetLoader.new(options: vsac_options, vsac_api_key: APP_CONFIG['vsac_api_key'])
  end
end

run Application.new