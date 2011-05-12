#!/usr/bin/env ruby

require 'rubygems'
require 'right_aws'
require 'ruby-debug'
require 'optparse'

options = {
  :ami => 'ami-359ea941',
  :group => 'default',
  :size => 'm1.small',
}

cmdline_options = OptionParser.new do |opts|
  opts.banner = "Usage: runchef.rb [options]"

  opts.on '-r', '--role ROLE' do |role|
    options[:role] = role
  end

  opts.on '-v', '--sdf-volume VOLUME' do |sdf|
    options[:sdf_volume] = sdf
  end

  opts.on '-g', '--group GROUP' do |group|
    options[:group] = group
  end

  opts.on '-a', '--ami AMI' do |ami|
    options[:ami] = ami
  end

  opts.on '-s', '--size SIZE' do |size|
    options[:size] = size
  end
end

cmdline_options.parse!

ec2 = RightAws::Ec2.new(ENV['AMAZON_ACCESS_KEY_ID'], ENV['AMAZON_SECRET_ACCESS_KEY'])
instances = ec2.run_instances(options[:ami],
                              min = 1,
                              max = 1,
                              groups = [options[:group]],
                              key = 'camelpunch',
                              user_data = File.read("/Users/andrew/dev/chef-repo/roles/#{options[:role]}-data.json"),
                              addressing = "public",
                              options[:size],
                              kernel = nil,
                              ramdisk = nil,
                              zone = "eu-west-1a",
                              monitoring = nil,
                              subnet_id = nil,
                              disable_api_termination = nil,
                              instance_initiated_shutdown_behaviour = nil,
                              block_device_mappings = [
                                {
                                  :device_name => '/dev/sda1',
                                  :ebs_delete_on_termination => false,
                                }
                              ])

instance_id = instances.first[:aws_instance_id]

state = ''
while state != 'running'
  state = ec2.describe_instances(instance_id).first[:aws_state]
  puts "#{instance_id} is #{state}"
  sleep 2
end

if options[:sdf_volume]
  puts "attaching #{options[:sdf_volume]} to /dev/sdf"
  ec2.attach_volume(options[:sdf_volume], instance_id, '/dev/sdf')
end

dns_name = ''
while dns_name.empty?
  sleep 2
  instances = ec2.describe_instances(instance_id)
  dns_name = instances.first[:dns_name]
end

sleepytime = 20
puts "sleeping #{sleepytime} seconds"
sleep sleepytime

success = false
while success == false
  success = system("ssh ubuntu@#{dns_name} echo 'Server is up!'")
  sleep 1
end

exec "ssh ubuntu@#{dns_name}"

