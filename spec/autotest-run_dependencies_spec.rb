require File.join(File.dirname(__FILE__), 'spec_helper.rb')

describe Autotest::RunDependencies do
  before(:each) do
    @dependency_parameters = {
      :name => 'Generic dependency',
      :command => 'script_ensuring_dependency_is_in_place arg arg',
      :satisfied_regexp => /success/,
      :errors_regexp => /error: (.*)/
    }
    @dependency = Autotest::RunDependencies.new(@dependency_parameters)
  end
  
  describe "#initialize" do
    it "sets the dependency name to the supplied name" do
      @dependency.name.should == @dependency_parameters[:name]
    end

    it "sets the dependency command to the supplied command" do
      @dependency.command.should == @dependency_parameters[:command]
    end
    
    it "sets the dependency satisfied_regexp to the supplied " + 
      "satisfied_regexp" do
      @dependency.satisfied_regexp.should == 
        @dependency_parameters[:satisfied_regexp]
    end
    
    it "sets the dependency errors_regexp to the supplied " + 
      "errors_regexp" do
      @dependency.errors_regexp.should ==
        @dependency_parameters[:errors_regexp]
    end
    
    it "sets the dependency last_dependency_check_time to the epoch" do
      @dependency.last_dependency_check_time.should == Time.at(0)
    end
  end
  
  describe ".add" do
    before(:each) do
      Autotest.stub(:add_hook)
    end
    
    it "creates a new dependecy with the parameters set in the block" do
      Autotest::RunDependencies.should_receive(:new).with(
        :name => 'Dependency name',
        :command => 'dependency_command',
        :satisfied_regexp => /satisfied/,
        :errors_regexp => /error/
      )
      Autotest::RunDependencies.add do |dependency|
        dependency.name = 'Dependency name'
        dependency.command = 'dependency_command'
        dependency.satisfied_regexp = /satisfied/
        dependency.errors_regexp = /error/
      end
    end
    
    it "adds an :initialize hook to autotest in which the dependencies' " + 
      "autotest instance is set" do
      mock_dependency = mock('dependency', :null_object => true)
      Autotest::RunDependencies.stub(:new).and_return(mock_dependency)

      mock_dependency.should_receive(:autotest_instance=).with('autotest')
      Autotest.
        should_receive(:add_hook).
        with(:initialize).
        and_yield('autotest')

      Autotest::RunDependencies.add do |dependency|
        dependency.name = 'Dependency name'
        dependency.command = 'dependency_command'
        dependency.satisfied_regexp = /satisfied/
        dependency.errors_regexp = /error/
      end
    end
    
    it "adds a :run_command hook to autotest in which the " + 
      "ensure_dependency_is_satisfied method is called on the dependency" do
      mock_dependency = mock('dependency', :null_object => true)
      Autotest::RunDependencies.stub(:new).and_return(mock_dependency)
      
      mock_dependency.should_receive(:ensure_dependency_is_satisfied)
      Autotest.
        should_receive(:add_hook).
        with(:run_command).
        and_yield('autotest')
      
      Autotest::RunDependencies.add do |dependency|
        dependency.name = 'Dependency name'
        dependency.command = 'dependency_command'
        dependency.satisfied_regexp = /satisfied/
        dependency.errors_regexp = /error/
      end
    end
    
    it "adds an :interrupt hook to autotest in which the reset method is " + 
      "called on the dependency" do
      mock_dependency = mock('dependency', :null_object => true)
      Autotest::RunDependencies.stub(:new).and_return(mock_dependency)
      
      mock_dependency.should_receive(:reset)
      Autotest.
        should_receive(:add_hook).
        with(:interrupt).
        and_yield('autotest')
      
      Autotest::RunDependencies.add do |dependency|
        dependency.name = 'Dependency name'
        dependency.command = 'dependency_command'
        dependency.satisfied_regexp = /satisfied/
        dependency.errors_regexp = /error/
      end
    end
    
    it "returns the created dependency" do
      mock_dependency = mock('dependency', :null_object => true)
      Autotest::RunDependencies.stub(:new).and_return(mock_dependency)
      
      Autotest::RunDependencies.add.should == mock_dependency
    end
  end
  
  describe "#ensure_dependency_is_satisfied" do
    before(:each) do
      @autotest = mock('autotest')
      @autotest.stub(:sleep).and_return(1)
      @dependency.stub(:`).and_return('success')
      @dependency.stub(:puts).and_return('true')
      @dependency.autotest_instance = @autotest
    end
    
    it "raises a runtime error if no command is set" do
      @dependency.command = nil
      expect {
        @dependency.ensure_dependency_is_satisfied
      }.to raise_error(RuntimeError)
    end
    
    it "raises a runtime error if no satisfied_regexp is set" do
      @dependency.satisfied_regexp = nil
      expect {
        @dependency.ensure_dependency_is_satisfied
      }.to raise_error(RuntimeError)
    end
    
    describe "if files have been modified since the last dependency test" do
      before(:each) do
        @dependency.last_dependency_check_time = Time.at(0)
        @autotest.stub(:find_files).and_return(
          {'file1' => Time.at(10), 'file2' => Time.at(20)}
        )
      end
      
      it "calls the stored command, redirecting stderr to stdout" do
        @dependency.should_receive(:`).with(@dependency.command + " 2>&1")
        @dependency.ensure_dependency_is_satisfied
      end
      
      it "outputs a message on a new line saying that it is about to " + 
        "check the dependency" do
        @dependency.should_receive(:puts).with(
          "\nChecking dependency: #{@dependency.name}"
        )
        @dependency.ensure_dependency_is_satisfied
      end
      
      describe "and the dependency is satisfied" do
        it "outputs a message saying the dependency has been satisfied" do
          @dependency.should_receive(:puts).with(
            /Dependency satisfied/
          )
          @dependency.ensure_dependency_is_satisfied
        end
        
        it "only calls the stored command once and returns" do
          @dependency.should_receive(:`).once
          @dependency.ensure_dependency_is_satisfied
        end
      end
      
      describe "and the dependency is not satisfied" do
        before(:each) do
          @dependency.stub(:`).and_return(
            "failed:\nerror: dependency not met\nerror: sorry mate",
            "success"
          )
          @autotest.stub(:find_files).and_return(
            {'file1' => Time.at(10), 'file2' => Time.at(20)},
            {'file1' => Time.now + 100, 'file2' => Time.at(20)}
          )
        end
        
        it "outputs a message saying the dependency hasn't been satisfied" do
          @dependency.should_receive(:puts).with(
            /Dependency not satisfied:/
          )
          @dependency.ensure_dependency_is_satisfied
        end
        
        it "outputs any lines in the command result that match the error " +
          "regexp on newlines and indented by a tab character" do
          @dependency.should_receive(:puts).with(
            /\s*dependency not met\n\s*sorry mate/
          )
          @dependency.ensure_dependency_is_satisfied
        end
        
        it "sleeps until some files have a modification time more recent " + 
          "than the last_dependency_check_time" do
          @autotest.stub(:find_files).and_return(
            {'file1' => Time.at(10), 'file2' => Time.at(20)},
            {'file1' => Time.at(10), 'file2' => Time.at(20)},
            {'file1' => Time.at(10), 'file2' => Time.at(20)},
            {'file1' => (Time.now + 100), 'file2' => Time.at(20)}
          )
          @dependency.should_receive(:sleep).with(@autotest.sleep).twice
          @dependency.ensure_dependency_is_satisfied
        end
        
        it "outputs a message saying that it is rechecking the dependency " + 
          "if a file is changed" do
          @dependency.should_receive(:puts).with(
            "Rechecking dependency: #{@dependency.name}"
          )
          @dependency.ensure_dependency_is_satisfied
        end
        
        it "reruns the dependency check until it is successful" do
          @autotest.stub(:find_files).and_return(
            {'file1' => Time.at(10), 'file2' => Time.at(20)},
            {'file1' => (Time.now + 100), 'file2' => Time.at(20)},
            {'file1' => (Time.now + 100), 'file2' => (Time.now + 200)}
          )
          @dependency.should_receive(:`).exactly(3).times.and_return(
            "failed:\nerror: dependency not met\nerror: sorry mate",
            "failed:\nerror: dependency not met\nerror: sorry mate",
            "success"
          )
          @dependency.ensure_dependency_is_satisfied
        end
      end
    end    
  end

  describe "#reset" do
    it "resets the last_dependency_check_time to the epoch" do
      @dependency.last_dependency_check_time = Time.now
      @dependency.reset
      @dependency.last_dependency_check_time.should == Time.at(0)
    end
  end
  
  describe "colourised output" do
    before(:each) do
      @autotest = mock('autotest')
      @autotest.stub(:sleep).and_return(1)
      @autotest.stub(:find_files).and_return(
        {'file1' => Time.at(10), 'file2' => Time.at(20)},
        {'file1' => Time.now + 100, 'file2' => Time.at(20)}
      )
      @dependency.stub(:`).and_return('success')
      @dependency.stub(:puts).and_return('true')
      @dependency.autotest_instance = @autotest
    end
    
    describe "#colourise_output" do
      describe "by default" do
        it "is true" do
          Autotest::RunDependencies.colourise_output.should be_true
        end
      end
    end

    describe "#colourise_output=" do
      it "allows colourised output to be turned off" do
        Autotest::RunDependencies.colourise_output = false
        Autotest::RunDependencies.colourise_output.should be_false
      end
    end
    
    describe "when on" do
      before(:each) do
        Autotest::RunDependencies.colourise_output = true
      end
      
      it "outputs the dependency satisfied message in green" do
        @dependency.should_receive(:puts).with(
          /\e\[32mDependency satisfied\n\e\[0m/
        )
        @dependency.ensure_dependency_is_satisfied
      end
      
      it "outputs the dependency not satisfied message and errors in red" do
        @dependency.stub(:`).and_return(
          "failed:\nerror: dependency not met\nerror: sorry mate",
          "success"
        )
        @autotest.stub(:find_files).and_return(
          {'file1' => Time.at(10), 'file2' => Time.at(20)},
          {'file1' => Time.now + 100, 'file2' => Time.at(20)}
        )
        
        @dependency.should_receive(:puts).with(
          /\e\[31mDependency\snot\ssatisfied:\n
            .*dependency\snot\smet.*\n
            .*sorry\smate.*\e\[0m/x
        )
        
        @dependency.ensure_dependency_is_satisfied
      end
    end
    
    describe "when off" do
      before(:each) do
        Autotest::RunDependencies.colourise_output = false
      end
      
      it "outputs the dependency satisfied message with no colour commands" do
        @dependency.should_receive(:puts).with(
          "-> Dependency satisfied\n"
        )
        @dependency.ensure_dependency_is_satisfied
      end
      
      it "outputs the dependency not satisfied message and errors with no " + 
        "colour commands" do
          @dependency.stub(:`).and_return(
            "failed:\nerror: dependency not met\nerror: sorry mate",
            "success"
          )
          @autotest.stub(:find_files).and_return(
            {'file1' => Time.at(10), 'file2' => Time.at(20)},
            {'file1' => Time.now + 100, 'file2' => Time.at(20)}
          )

          @dependency.should_receive(:puts).with(
            "-> Dependency not satisfied:\n" + 
            "    dependency not met\n" + 
            "    sorry mate"
          )

          @dependency.ensure_dependency_is_satisfied
      end
    end
  end

end