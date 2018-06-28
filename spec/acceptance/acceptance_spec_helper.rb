# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"

require File.expand_path("../../../config/environment", __FILE__)

require "rspec/rails"
require "capybara/rspec"
require "capybara"
require "capybara/dsl"
require "selenium-webdriver"
require "site_prism"


Capybara.register_driver :selenium do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--disable-infobars")
  options.add_argument("--lang=de")
  options.add_argument("--disable-gpu")

  options.add_preference("extensions.password_manager_enabled", false)
  options.add_preference("download.prompt_for_download", false)
  options.add_preference("credentials_enable_service", false)

  # Chromedriver.set_version "2.33"
  Capybara::Selenium::Driver.new(app, { browser: :chrome, options: options })
end
Capybara.default_driver = :selenium
Capybara.javascript_driver = :selenium

Capybara.default_max_wait_time = 20
Capybara.automatic_reload = true

# Capybara::Screenshot.register_filename_prefix_formatter(:rspec) do |example|
#   example.location.gsub(/^\.\//, "").tr("/", "_").tr(":", "-")
# end

Dir[Rails.root.join("spec/acceptance/{sections,pages}/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{ ::Rails.root }/spec/fixtures"

  # Custom settings for debugging acceptance test output
  # config.add_setting :verbose_cookies
  # config.add_setting :verbose_capybara_visit, default: true

  # Configure verbose cookies for debugging
  # config.verbose_cookies        = ENV["RSPEC_VERBOSE_COOKIES"]        if ENV.key?("RSPEC_VERBOSE_COOKIES")
  # config.verbose_capybara_visit = ENV["RSPEC_VERBOSE_CAPYBARA_VISIT"] if ENV.key?("RSPEC_VERBOSE_CAPYBARA_VISIT")

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  config.before(:example) do |x|
    metadata = x.metadata
    # print ANSI.green { "\n" + "=" * 80 + "\n" + "== #{ metadata[:full_description] }\n" + "=" * 80 + "\n\n" }
    RSpec.configuration.reporter.message "==>>> #{ metadata[:location] } #{ metadata[:description_args] }"
  end

  config.after(:example) do
    # See also comment on require capybara-screenshot below!
    # print ANSI.white_on_black { "** Resetting Capybara Session\n" }
    Capybara.reset_sessions!
  end

  if ENV["TEST_ENV_NUMBER"]
    statistical_assign = {}
    partitions_exp_time = []
    if File.exist?("tmp/last_parallel_runtime_rspec.log")
      test_duration = `grep 'runtime_log:' tmp/last_parallel_runtime_rspec.log`
      sub_result = {}
      test_duration.each_line do |line|
        parts = line.split(":")
        sub_result[parts[1] + ":" + parts[2]] = parts[3]
      end
      sorted_sub_result = sub_result.sort_by { |_location, duration| duration.to_f }.reverse
      RSpec.configuration.reporter.message(sorted_sub_result.map { |row| row.join(", ") })
      i = 0
      sorted_sub_result.each do |example|
        statistical_assign[example.first] = i + 1
        partitions_exp_time[i] = partitions_exp_time[i].nil? ? example.last.to_f : partitions_exp_time[i] + example.last.to_f
        i += 1
        i = i % ENV["NUMBER_TEST_INSTANCES"].to_i
      end
    end

    def random_assign(description)
      test_number = ENV["TEST_ENV_NUMBER"]
      test_number = 1 if test_number.blank?
      number_test_instances = ENV["NUMBER_TEST_INSTANCES"].to_i if ENV["NUMBER_TEST_INSTANCES"].present?
      number_test_instances = Parallel.processor_count if number_test_instances.blank?

      calc_partition_number = (Digest::MD5.hexdigest(description).split("").map(&:ord).join.to_i % number_test_instances).to_i + 1
      RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] || 1 }] fallback partition: #{ description } -> #{ calc_partition_number }")

      calc_partition_number == test_number.to_i
    end

    def round_robin_assign(description)
      test_number = ENV["TEST_ENV_NUMBER"]
      test_number = if test_number.blank?
                      1
                    else
                      test_number.to_i
                    end

      number_test_instances = ENV["NUMBER_TEST_INSTANCES"].to_i if ENV["NUMBER_TEST_INSTANCES"].present?
      number_test_instances = Parallel.processor_count if number_test_instances.blank?

      $fallback_partition_nr = 0 if $fallback_partition_nr.nil?
      $fallback_partition_hash = {} if $fallback_partition_hash.nil?
      # $fallback_partition_nr[test_number] = 0 if $fallback_partition_nr[test_number].nil?
      if $fallback_partition_hash[description].nil?
        calc_partition_number = ($fallback_partition_nr % number_test_instances) + 1
        $fallback_partition_nr += 1
      else
        calc_partition_number = $fallback_partition_hash[description]
      end

      if calc_partition_number == test_number.to_i
        RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] || 1 }] {#{ $fallback_partition_nr }} fallback partition: #{ description } -> #{ calc_partition_number }")
      end

      calc_partition_number == test_number.to_i
    end

    if statistical_assign.empty?
      RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] }] no partition defined using fallback assignment for all tests")
      config.filter_run location: lambda { |description|
        #        random_assign description
        round_robin_assign description
      }
    else
      RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] }] partitions are defined so first try to assign the tests depending on the last runtime")
      config.filter_run location: lambda { |location|
        test_number = ENV["TEST_ENV_NUMBER"].empty? ? 1 : ENV["TEST_ENV_NUMBER"].to_i
        #        if partitions[test_number - 1].try { |partition| partition.detect { |example_location| example_location == location }}
        test_part_num = statistical_assign[location]
        if test_part_num.nil?
          #          random_assign location
          round_robin_assign location
        elsif test_part_num == test_number
          RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] }] using partition: #{ location } -> #{ test_part_num } : return true")
          true
        else
          RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] }] using partition: #{ location } -> #{ test_part_num } : return false")
          false
        end
      }
    end

    partitions_exp_time.each_with_index do |part_exp_time, idx|
      RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] }] expected runtime for patition #{ idx }: #{ part_exp_time }")
    end

    statistical_assign.each do |test, partition_nr|
      RSpec.configuration.reporter.message("[##{ ENV['TEST_ENV_NUMBER'] }] run #{ test } -> #{ partition_nr }")
    end
  end

end

# Automatically creating a screenshot by capybara-screenshot in case of an error is triggered by an
# after hook A. If this hook is executed after the after hook that resets the capybara session (B)
# no screenshot is created, because the capybara session is ended already. Loading capybara-screenshot
# here makes sure that A runs before B (later added hook are executed first)

SitePrism.configure do |config|
  config.use_implicit_waits = true
end

module SitePrism
  module FastElementNonExistence
    private

    # def add_helper_methods(name, *find_args)
    #   super
    #   create_fast_existence_checker name, *find_args
    #   create_fast_nonexistence_checker name, *find_args
    # end

    # def create_fast_nonexistence_checker(element_name, *find_args)
    #   method_name = "fast_has_no_#{ element_name }?"
    #   create_helper_method method_name, *find_args do
    #     define_method method_name do |*_runtime_args|
    #       has_no_selector?(*find_args)
    #     end
    #   end
    # end

    # def create_fast_existence_checker(element_name, *find_args)
    #   method_name = "fast_has_#{ element_name }?"
    #   create_helper_method method_name, *find_args do
    #     define_method method_name do |*_runtime_args|
    #       all(*find_args).any?
    #     end
    #   end
    # end
  end
end

module SitePrism
  class Page
    extend SitePrism::FastElementNonExistence
  end
end

def unique_string
  (0..6).map { [("a".."z"), ("A".."Z")].flat_map(&:to_a)[rand(52)] }.join + Time.now.to_f.to_s
end

def unique_name
  (0..16).map { [("a".."z"), ("A".."Z")].flat_map(&:to_a)[rand(52)] }.join
end

def unique_user_name
  (0..6).map { [("a".."z"), ("A".."Z")].flat_map(&:to_a)[rand(52)] }.join
end

def unique_client_name
  "PaymentATest_#{ unique_string }"
end

class Capybara::Selenium::Driver
  def reset_browser
    @browser = nil
  end
end
