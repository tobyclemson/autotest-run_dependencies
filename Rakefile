require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'jeweler'

Rake::RDocTask.new do |rd|
  rd.main = "README.rdoc"
  rd.rdoc_files.include("README.rdoc", "lib/**/*.rb")
  rd.rdoc_dir = 'doc'
  rd.title = 'Autotest::RunDependencies RDoc Documentation'
end

Spec::Rake::SpecTask.new 

Jeweler::Tasks.new do |gemspec|
  gemspec.name = "autotest-run_dependencies"
  gemspec.summary = "Test dependencies for autotest."
  gemspec.description = <<EOF
This gem provides a mechanism through which it is possible to specify that 
an arbitrary number of external dependencies are satisfied before a test 
run can be executed.

Dependencies are added by specifying a name, command, satisfied_regexp and 
errors_regexp parameter for each. The command refers to a script that is 
run to satisfy or test the dependency. If the output of the command 
(either to standard output or standard error) matches the satisfied_regexp 
then the dependency is considered met otherwise any lines in the output 
matching errors_regexp are output and the dependency test waits for changes 
to the codebase before trying to satisfy the dependency again.
EOF
  gemspec.email = "tobyclemson@gmail.com"
  gemspec.homepage = "http://github.com/tobyclemson/autotest-run_dependencies"
  gemspec.authors = ["Toby Clemson"]
  gemspec.add_dependency('ZenTest', '>= 3.9.0')
  gemspec.files.exclude ".gitignore"
  gemspec.rdoc_options << '--main'  << 'README.rdoc' << 
                          '--title' << 'Autotest::RunDependencies RDoc Documentation' << 
                          '--line-numbers'
  gemspec.development_dependencies << 'rspec'
end

Jeweler::GemcutterTasks.new