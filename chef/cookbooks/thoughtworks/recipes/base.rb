#
# Cookbook Name:: thoughtworks
# Recipe:: base
#
# Copyright 2016, krogebry.com
#
# All rights reserved - Do Not Redistribute
#

['aws-cli', 'mlocate'].each do |package_name|
  package package_name
end


