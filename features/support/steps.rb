When /^I run the following:$/ do
	|command_string|

	command_string.gsub! "\n", " "

	@output = `bundle exec #{command_string}`

	@status = $?.exitstatus

end

Then /^the exit status should be (\d+)$/ do
	|status_str|

	@status.should == status_str.to_i

end

Then /^the output should match:$/ do
	|output_re_str|

	output_re = /^#{output_re_str}$/

	@output.strip.should match output_re

end
