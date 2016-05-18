environment_path format('%s/dev/stargate/chef/environments', ENV['HOME'])

log_level :info
log_location STDOUT

role_path format('%s/dev/stargate/chef/roles', ENV['HOME'])

cookbook_path [
  format('%s/dev/stargate/chef/cookbooks', ENV['HOME']),
  format('%s/.chef/', ENV['HOME'])
]

data_bag_path format('%s/dev/stargate/chef/data_bags', ENV['HOME'])
