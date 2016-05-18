FS_ROOT = File.join(File::SEPARATOR, 'opt', 'maciepoo-chef')
environment_path format('%s/environments', FS_ROOT)
log_level :info
log_location STDOUT
role_path format('%s/roles', FS_ROOT)
cookbook_path [ format('%s/cookbooks', FS_ROOT) ]
data_bag_path format('%s/data_bags', FS_ROOT)
