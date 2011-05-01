#!/usr/bin/env ruby

require 'rubygems'
require 'right_aws'
require 'ruby-debug'

site = ARGV[0]
sdf_volume = ARGV[1]

group = ARGV[2] || 'default'
ami = ARGV[3] || 'ami-8d3502f9'
size = ARGV[4] || 'm1.small'

ec2 = RightAws::Ec2.new(ENV['AMAZON_ACCESS_KEY_ID'], ENV['AMAZON_SECRET_ACCESS_KEY'])
instances = ec2.run_instances(ami,
                              min = 1,
                              max = 1,
                              groups = [group],
                              key = 'camelpunch',
                              user_data = File.read("/Users/andrew/dev/chef-repo/roles/#{site}-data.json"),
                              "public",
                              size,
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

if sdf_volumn && !sdf_volume.empty?
  puts "attaching #{sdf_volume} to /dev/sdf"
  ec2.attach_volume(sdf_volume, instance_id, '/dev/sdf')
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

