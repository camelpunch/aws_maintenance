#!/usr/bin/env ruby

require 'rubygems'
require 'aws'
require 'active_support'

unless ENV['SNAPSHOT_VOLUME']
  raise "Please provide a volume ID with SNAPSHOT_VOLUME environment variable"
end

ec2 = Aws::Ec2.new(ENV['AMAZON_ACCESS_KEY_ID'], 
                   ENV['AMAZON_SECRET_ACCESS_KEY'], 
                   :region => (ENV['REGION'] || 'eu-west-1'))

snapshots = ec2.describe_snapshots

old_snapshots = snapshots.select do |snapshot|
  (snapshot[:aws_started_at] < 1.week.ago) &&
    snapshot[:aws_volume_id] == ENV['SNAPSHOT_VOLUME']
end

snapshots_since_this_morning = snapshots.select do |snapshot|
  (snapshot[:aws_started_at] > Date.today) &&
    snapshot[:aws_volume_id] == ENV['SNAPSHOT_VOLUME']
end

old_snapshots.each do |snapshot|
  puts "Deleting snapshot #{snapshot[:aws_id]} from #{snapshot[:aws_started_at]}"
  ec2.delete_snapshot snapshot[:aws_id]
end

if snapshots_since_this_morning.empty?
  puts "Creating snapshot"
  puts ec2.create_snapshot(ENV['SNAPSHOT_VOLUME']).to_yaml
else
  puts "The following snapshots were created since this morning:"
  puts snapshots_since_this_morning.to_yaml
end

