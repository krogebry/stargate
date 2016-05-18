##
# Let's do some stuff.
##
FS_ROOT = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift FS_ROOT
require 'pp'
require 'json'
require 'yaml'
require 'base64'
require 'logger'
require 'fileutils'
require 'deep_merge'

APPLICATION_NAME = 'maciepoo'.freeze

Log = Logger.new(STDOUT)

require 'lib/maciepoo.rb'
require 'lib/maciepoo/stack.rb'

require 'lib/krogebry.rb'

Cache = Krogebry::FileCache.new(File.join(File::SEPARATOR, 'tmp', APPLICATION_NAME))

namespace :cloud do

  desc 'Compile things'
  task :compile, :env_name, :target, :version do |t, args|
    app_cfg = Maciepoo::Stack.get_config(args)
    # pp app_cfg
    begin
      app = Maciepoo.get_app(app_cfg)
      app.compile
      app.save

    rescue => e
      Log.fatal(format('Stack error: %s', e))
      pp e.backtrace

    end
  end

  desc 'Deploy a stack.'
  task :deploy, :env_name, :target, :version do |t, args|
    app_cfg = Maciepoo::Stack.get_config(args)
    begin
      app = Maciepoo.get_app(app_cfg)
      app.compile
      app.save
      #app.validate

      exists = false

      if exists == true
        app.update
      else
        begin
          Log.debug('Launching')
          app.launch(false)
        rescue => e
          Log.fatal(format('Failure: %s', e))
          pp e.backtrace
        end
      end

    rescue => e
      Log.fatal(format('Stack error: %s', e))
      pp e.backtrace

    end

  end

  desc 'Syntax check a template.'
  task :validate, :env_name, :target, :version do |t, args|
    app_cfg = Maciepoo.Stack.get_config(args)
    begin
      app = Maciepoo.get_app(app_cfg)
      app.compile
      app.save
      app.validate

    rescue => e
      Log.fatal(format('Stack error: %s', e))
      pp e.backtrace

    end
  end
end

namespace :chef do
  desc 'Lint check the chef bits.'
  task :lint do
  end

  desc 'Package chef bits.'
  task :package, :version, :dry_run do |t, args|
    version = args[:version]
    dr = args[:dry_run].to_bool || false

    export_dir = File.join(File::SEPARATOR, 'tmp', 'export', format('maciepoo-%s', version))
    FileUtils.mkdir_p(export_dir) unless File.exist?(export_dir)

    #berks_dir = File.join(ENV['HOME'], '.chef', 'cookbooks')
    #FileUtils.mkdir_p(berks_dir) unless File.exist?(berks_dir)

    ## User berks to get our dependant cookbooks.
    cookbooks_dir = File.join(export_dir, 'cookbooks')
    FileUtils.mkdir_p(cookbooks_dir) unless File.exist?(cookbooks_dir)
    cmd_berks = format('berks vendor -b chef/Berksfile %s', cookbooks_dir)
    Log.debug(format('CMD(berks): %s', cmd_berks))
    system(cmd_berks) unless dr

    ## Add in our own cookbooks.
    cmd_cp_books = format('rsync -r chef/cookbooks/* %s', cookbooks_dir)
    Log.debug(format('CMD(cp_books): %s', cmd_cp_books))
    system(cmd_cp_books) unless dr

    ## Copy roles
    roles_dir = File.join(export_dir, 'roles')
    FileUtils.mkdir_p(roles_dir) unless File.exist?(roles_dir)
    cmd_cp_roles = format('rsync -r chef/roles/* %s/', roles_dir)
    Log.debug(format('CMD(cp_roles): %s', cmd_cp_roles))
    system(cmd_cp_roles) unless dr

    ## Copy enviornments
    environments_dir = File.join(export_dir, 'environments')
    FileUtils.mkdir_p(environments_dir) unless File.exist?(environments_dir)
    cmd_cp_environments = format('rsync -r chef/environments/* %s/', environments_dir)
    Log.debug(format('CMD(cp_environments): %s', cmd_cp_environments))
    system(cmd_cp_environments) unless dr

    ## Package everything up.
    pkg_name = File.join(File::SEPARATOR, 'tmp', format('maciepoo-%s.tar.bz2', version))
    cmd_package = format('cd %s ; cd .. ; tar -cjpf %s ./', export_dir, pkg_name)
    Log.debug(format('CMD(package): %s', cmd_package))
    system(cmd_package) unless dr
  end

  desc 'Deploy a packaged archive to s3'
  task :deploy, :version do |t, args|
    version = args[:version]

    s3_bucket_root = 's3://maciepoo/chef/solo'

    ## Upload DNA strands.
    s3_dna_bucket = format('%s/dna', s3_bucket_root)

    Dir.glob(File.join('chef', 'dna', '*.json')).each do |dna_strand|
      cmd_cp_dna = format('aws s3 cp %s %s/', File.join(dna_strand), s3_dna_bucket)
      Log.debug(format('CMD(cp_dna): %s', cmd_cp_dna))
      system(cmd_cp_dna)
    end

    ## Send the archive to S3.
    fs_archive = File.join(File::SEPARATOR, 'tmp', format('maciepoo-%s.tar.bz2', version))
    Log.debug(format('Sending: %s', fs_archive))

    s3_bucket_name = format('%s/archives/%s', s3_bucket_root, File.basename(fs_archive))

    cmd_s3 = format('aws s3 cp %s %s', fs_archive, s3_bucket_name)
    Log.debug(format('CMD(s3): %s', cmd_s3))
    system(cmd_s3)
  end
end

namespace :cache do
  task :clear do
    Cache.clear_all
  end
end
