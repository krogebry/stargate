##
# Basic stack thingie.
##

module Maciepoo
  ## Power drill for building CF stacks.
  class Stack
    @cfg = {}
    @name = ''
    @tags = []
    @stack = {}
    @params = []

    def self.get_config(args)
      ## Gobble up the configuration data.
      ## Start with the general high-level configs, then work down to the more specific things.
      main_cfg = File.join(format('etc/%s.yaml', APPLICATION_NAME))
      app_cfg = YAML.load(File.read(main_cfg)).to_h

      target = args[:target] || 'app'
      version = args[:version] || '0.1.0'

      env_cfg = File.join(format('etc/cloudformation/%s.yaml', args[:env_name]))
      env_yaml = YAML.load(File.read(env_cfg)).to_h

      app_cfg['name'] = format('%s-%s-%s', args[:env_name], args[:target], version)
      app_cfg['region'] = 'us-east-1'

      app_cfg['target'] = target
      app_cfg['version'] = version
      app_cfg['env_name'] = args[:env_name]

      app_cfg.deep_merge(env_yaml)
    end

    def initialize(cfg)
      @cfg = cfg
      @name = cfg['name']
    end

    def compile
      @stack = {
        # Outputs: {},
        Mappings: {},
        Resources: {},
        Parameters: {}
      }

      # @stack[:Outputs].deep_merge!(outputs(
      @stack[:Mappings].deep_merge!(mappings)
      @stack[:Resources].deep_merge!(resources)
      @stack[:Parameters].deep_merge!(parameters)
      #pp @stack
    end

    def validate
      cmd_validate = format('aws cloudformation validate-template --template-body file://%s', out_file)
      Log.debug(format('CMD(validate): %s', cmd_validate))
      system(cmd_validate)
    end

    def stack_name
      @name.tr('.', '-').tr(' ', '-')
    end

    def get_tpl(type, chunk_name, namespace = nil)
      json = JSON.parse(File.read(File.join('vendor', 'aws', 'cloudformation', type, format('%s.json', chunk_name))))
      json = { namespace => json[json.keys[0]] } if namespace
      json
    end

    def get_azs_for_subnet(subnet_id)
      filters = format('Name=subnet-id,Values=%s', subnet_id)
      key = format('subnet-%s', ::Base64.encode64(filters))
      data = Cache.get_json(key) do
        cmd_get_subnets = format('aws ec2 describe-subnets --filters %s', filters)
        Log.debug('CMD(get_subnets: %s', cmd_get_subnets)
        `#{cmd_get_subnets}`
      end
      pp data
    end

    def get_vpc(inf_name, inf_version)
      filters = {
        version: inf_version,
        environment_name: inf_name
      }.map { |k, v| format('Name=%s,Values=%s', format('tag:%s', k), v) }.join('" "')
      
      key = format('vpc-%s', ::Base64.urlsafe_encode64(filters))

      data = Cache.get_json(key) do
        cmd_get_vpc = format('aws ec2 describe-vpcs --filters "%s"', filters)
        Log.debug(format('CMD(get_vpc): %s', cmd_get_vpc))
        ## TODO: Validation and execution testing.
        `#{cmd_get_vpc}`
      end
      data['Vpcs'][0]
    end

    def find_ami(query)
      filters = query.map { |k, v| format('Name=%s,Values=%s', format('tag:%s', k), v) }.join(',')

      key = format('ami-%s', ::Base64.urlsafe_encode64(filters))

      data = Cache.get_json(key) do
        cmd_get_images = format('aws ec2 describe-images --filters %s', filters)
        Log.debug(format('CMD(get_vpc): %s', cmd_get_images))
        `#{cmd_get_images}`
      end
      #pp data

      data['Images']
    end

    def get_subnets(vpc_id, params)
      filters = params.map { |k, v| format('Name=%s,Values=%s', format('tag:%s', k), v) }.join('" "')
      filters << format(' "Name=vpc-id,Values=%s"', vpc_id)

      key = format('vpc-%s', ::Base64.urlsafe_encode64(filters))

      data = Cache.get_json(key) do
        cmd_get_subnets = format('aws ec2 describe-subnets --filters %s', filters)
        Log.debug(format('CMD(get_vpc): %s', cmd_get_subnets))

        ## TODO: Validation and execution testing.
        `#{cmd_get_subnets}`
      end

      data['Subnets']
    end

    def tags
      data = []
      data.push('Key' => 'name', 'Value' => @cfg['name'])
      data.push('Key' => 'owner', 'Value' => ENV['USER'])
      data.push('Key' => 'version', 'Value' => @cfg['version'])
      data.push('Key' => 'environment_name', 'Value' => @cfg['environment']['name'])
      data
    end

    def params
      data = {}
      data
    end

    def launch(dry_run = false)
      tags = tags()
      # pp tags
      params = params().map { |k, v| { 'ParameterKey' => k, 'ParameterValue' => v } }
      # pp params

      cmd_json = get_tpl('', 'create-stack')

      cmd_json['StackName'] = stack_name
      cmd_json['Parameters'] = params
      cmd_json['TemplateBody'] = File.read(out_file)

      cmd_json.delete('TemplateURL')
      cmd_json.delete('TimeoutInMinutes')
      cmd_json.delete('NotificationARNs')
      #cmd_json.delete('Capabilities')
      cmd_json['Capabilities'] = ['CAPABILITY_IAM']
      cmd_json.delete('ResourceTypes')
      cmd_json.delete('OnFailure')
      cmd_json.delete('StackPolicyBody')
      cmd_json.delete('StackPolicyURL')
      cmd_json['Tags'] = tags

      # pp cmd_json

      f = File.open('/tmp/cmd.json', 'w')
      f.puts(cmd_json.to_json)
      f.close

      cmd_launch = format('aws cloudformation create-stack --cli-input-json \'%s\'', cmd_json.to_json)
      # Log.debug(format('CMD(launch): %s', cmd_launch))

      system(cmd_launch) unless dry_run
    end

    def update
      cmd_validate = format('aws cloudformation update-stack --template-body file://%s', out_file)
      Log.debug(format('CMD(validate): %s', cmd_validate))
      system(cmd_validate)
    end

    def parameters
      {}
    end

    def outputs
      {}
    end

    def mappings
      subnets = get_tpl('mappings', 'subnets')
      subnets
    end

    def resources
      {}
    end

    def out_file
      File.join(File::SEPARATOR, 'tmp', format('cf_%s', @name))
    end

    def save
      f = File.open(out_file, 'w')
      f.puts(@stack.to_json)
      f.close
    end
  end
end

require 'lib/maciepoo/security.rb'
require 'lib/maciepoo/application.rb'
require 'lib/maciepoo/infrastructure.rb'
