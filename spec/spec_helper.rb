begin
  require 'spec'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rspec'
  require 'spec'
end

$:.unshift(
  File.join(File.dirname(__FILE__), '..', 'lib')
) unless 
  $:.include?(File.join(File.dirname(__FILE__), '..', 'lib')) || 
  $:.include?(
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
  )

require 'autotest/run_dependencies'