require 'rubygems'
require 'autotest'
require 'ostruct'

# Autotest::RunDependencies
#
# == FEATURES:
# * Allows an arbitrary number of dependencies to be set that must be 
#   satisfied before a test run is executed.
# * The dependencies take the form of scripts that output to stdout or stderr.
# * The dependency is considered satisfied if the output matches some user
#   specified regular expression.
# * If the dependency is not satisfied, a list of errors is printed where
#   each error is a match of the user supplied errors regular expression.
# * By default, output is colourised green on success, red on failure.
# * Colourisation can be turned off.
#
# == SYNOPSIS:
# PROJECT_ROOT/.autotest
#   require 'autotest/run_dependencies.rb'
#   
#   # Add a dependency to the run dependencies
#   Autotest::RunDependencies.add do |dependency|
#     dependency.name = 'some dependency'
#     dependency.command = 'echo "success"'
#     dependency.satisfied_regexp = /success/
#     dependency.errors_regexp = /error (.*)/
#   end
class Autotest::RunDependencies
  
  attr_accessor :name,
                :command, 
                :satisfied_regexp, 
                :errors_regexp, 
                :last_dependency_check_time,
                :autotest_instance
  
  # By default the output produced is colourised.
  @@colourise_output = true
  
  class << self
    # Returns true if Autotest::RunDependencies is currently 
    # configured to colourise its output, false otherwise.
    def colourise_output
      @@colourise_output
    end
    alias_method :colorize_output, :colourise_output 
  
    # Sets whether or not Autotest::RunDependencies should colourise
    # its output.
    def colourise_output=(boolean)
      @@colourise_output = boolean
    end
    alias_method :colorize_output=, :colourise_output=
  end
  
  # Adds a test dependency to any autotest test run.
  #
  # Expects a block to be supplied that sets the dependency parameters, e.g.,
  #
  #   Autotest::RunDependencies.add do |dependency|
  #     dependency.name = 'some dependency'
  #     dependency.command = 'echo "success"'
  #     dependency.satisfied_regexp = /success/
  #     dependency.errors_regexp = /error (.*)/
  #   end
  #
  # Returns the dependency (an instance of Autotest::RunDependencies). 
  # 
  # It is possible not to pass a block and set the parameters on the returned 
  # object but if a dependency object has no #command and #satisfied_regexp 
  # set then on calling #ensure_dependency_is_satisfied a RuntimeError is 
  # raised.
  # 
  # The method also registers the relevant hooks with Autotest so that the 
  # dependency is required to be satisfied before the test run.
  def self.add(&block)
    parameters = OpenStruct.new
    block.call(parameters) if block
    dependency = self.new(
      :name => parameters.name,
      :command => parameters.command,
      :satisfied_regexp => parameters.satisfied_regexp,
      :errors_regexp => parameters.errors_regexp
    )

    Autotest.add_hook(:initialize) do |autotest|
      dependency.autotest_instance = autotest
      false
    end

    Autotest.add_hook(:run_command) do |autotest|
      dependency.ensure_dependency_is_satisfied
      false
    end

    Autotest.add_hook(:interrupt) do |autotest|
      dependency.reset
      false
    end
    
    return dependency
  end
                
  # Creates an instance of Autotest::RunDependencies.
  #
  # The optional _options_ hash can contain values for the keys :name, 
  # :command, :satisfied_regexp and :errors_regexp. Any other entries will be
  # ignored. The values of the parameters are used as default values for the
  # instance's attributes.
  def initialize(options = {})
    self.name = options[:name]
    self.command = options[:command]
    self.satisfied_regexp = options[:satisfied_regexp]
    self.errors_regexp = options[:errors_regexp]
    self.last_dependency_check_time = Time.at(0)
  end
  
  # Runs the dependency test command if any files have been modified since the
  # last time the dependency was checked. If the dependency is satisfied, 
  # i.e., the output of the command matches the regular expression in 
  # the #satisfied_regexp attribute, then the test run is allowed to continue, 
  # otherwise the method prints any lines in the output that match the regular 
  # expression in the #errors_regexp attribute and waits for further changes 
  # to the codebase before trying to test the dependency again.
  # 
  # This method raises a RuntimeError unless both the #command and 
  # #satisfied_regexp attributes are set.
  def ensure_dependency_is_satisfied
    unless self.command and self.satisfied_regexp
      raise(
        RuntimeError, 
        "Dependencies must have at least a command and a satisfied_regexp " +
        " set."
      )
    end
    if find_changed_files
      puts "\nChecking dependency: #{self.name}"
      loop do
        self.last_dependency_check_time = Time.now
        test_dependency
        if satisfied?
          puts "-> #{green_command}Dependency satisfied\n#{no_colour_command}"
          break
        else
          puts "-> #{red_command}Dependency not satisfied:\n" + 
            "#{errors}#{no_colour_command}"
          wait_for_changes
          puts "Rechecking dependency: #{self.name}"
        end
      end
    end
  end
  
  # Resets the dependency state so that it will recheck the dependency during
  # the next test run regardless of whether any files have changed.
  def reset
    self.last_dependency_check_time = Time.at(0)
  end
  
  private
    
    # Runs the dependency command redirecting stderr into stdout.
    def test_dependency
      @results = `#{self.command} 2>&1`
    end
    
    # Returns true if the output of the dependency command matches the 
    # #satisfied_regexp, false otherwise.
    def satisfied?
      (@results =~ self.satisfied_regexp) ? true : false
    end
    
    # Returns a string of errors matching the #errors_regexp on separate lines
    # indented by four spaces.
    def errors
      "    " + @results.scan(self.errors_regexp).join("\n    ")
    end
    
    # Sleeps until files in the codebase are modified.
    def wait_for_changes
      sleep(self.autotest_instance.sleep) until find_changed_files
    end
    
    # Searches the codebase for files that have been modified since the last
    # dependency check.
    def find_changed_files
      changed_files = self.autotest_instance.
        find_files.
        delete_if do |filename, modification_time| 
          modification_time < self.last_dependency_check_time
        end
        
      changed_files.empty? ? false : true
    end
    
    # Returns a string representing the colour code for green output if 
    # output colorisation is turned on.
    def green_command
      self.class.colourise_output ? "\e\[32m" : nil
    end
    
    # Returns a string representing the colour code for red output if 
    # output colorisation is turned on.
    def red_command
      self.class.colourise_output ? "\e\[31m" : nil
    end
    
    # Returns a string representing the colour code for colourless output if 
    # output colorisation is turned on.
    def no_colour_command
      self.class.colourise_output ? "\e\[0m" : nil
    end
end