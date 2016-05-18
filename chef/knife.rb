environment_path format('%s/dev/thoughtworks/chef/environments', ENV['HOME'])

log_level :info
log_location STDOUT

role_path format('%s/dev/thoughtworks/chef/roles', ENV['HOME'])

cookbook_path [
  format('%s/dev/thoughtworks/chef/cookbooks', ENV['HOME']),
  format('%s/.chef/', ENV['HOME'])
]

data_bag_path format('%s/dev/thoughtworks/chef/data_bags', ENV['HOME'])
