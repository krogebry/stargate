##
# Basic stack thingie.
##

module Stargate
  class Application < Stack
    def parameters
      data = {}
      ['ssh', 'vpc', 'keyname', 'chef', 'domain' ].each do |name|
        data.deep_merge!(get_tpl('parameters', name))
      end
      data
    end

    def params
      data = super

      inf_version = @cfg['environment']['aws']['cloudformation']['inf_version']
      vpc = get_vpc(@cfg['environment']['name'], inf_version)

      if vpc == nil
        raise Exception.new(format('Unable to find VPC.  Launch with: rake cloud:deploy[\'training, inf, %s\'].', inf_version))
        ## Remember: the man loves you.
      end

      vpc_id = vpc['VpcId']

      subnets = get_subnets(vpc_id, {'Network' => 'Public'})
      if subnets == nil
        raise Exception.new('Unable to find subnet!') 
      end
      
      base_ami_version = @cfg['environment']['aws']['cloudformation']['images']['krogebry-base-hvm']
      ami = find_ami( 'Name' => 'krogebry-base-hvm', 'Version' => base_ami_version )

      data['VPCId'] = vpc_id
      data['KeyName'] = @cfg['environment']['aws']['cloudformation']['key_name']
      data['Subnets'] = subnets[0]['SubnetId']
      data['AZs'] = subnets[0]['AvailabilityZone']
      data['ImageId'] = ami[0]['ImageId']

      data
    end

    def resources
      chef_version = @cfg['environment']['chef']['version']

      script = [ "#!/bin/bash -xe\n",
        "mkdir -p /etc/chef\n",
        "aws s3 cp s3://maciepoo/chef/solo/ /etc/chef/\n",
        format("aws s3 cp s3://maciepoo/chef/solo/archives/chef_cookbooks-%s.tar.bz2 /etc/chef/\n", chef_version),
        format("aws s3 cp s3://maciepoo/chef/solo/dna/bastion.json /etc/chef/dna.json\n", chef_version),
        format("chef-solo -c /etc/chef/solo.rb -j /etc/chef/dna.json -E %s\n", @cfg["environment"]["name"]),
        "/opt/aws/bin/cfn-init -v ",
        " --stack ", { "Ref" => "AWS::StackName" },
        " --resource LaunchConfig ",
        " --region ", { "Ref" => "AWS::Region" }, "\n",
        "/opt/aws/bin/cfn-signal -e $? ",
        " --stack ", { "Ref" => "AWS::StackName" },
        " --resource WebServerGroup ",
        " --region ", { "Ref" => "AWS::Region" }, "\n" ]

      env_cfg = @cfg['environment']['aws']['cloudformation']
      profiles = env_cfg['profiles']

      iam = get_tpl('resources', 'iam')

      ## Create the ELB's
      elb_fe = get_tpl('resources', 'elb', 'ELB')      
      elb_be = get_tpl('resources', 'elb', 'ELB')

      ## Launch configs.
      lc_fe = JSON::parse(File.read(File.join('vendor', 'aws', 'cloudformation', 'resources', 'launch_config.json')))
      lc_fe['LaunchConfig']['Properties']['ImageId'] = { 'Ref' => 'ImageId' }
      lc_fe['LaunchConfig']['Properties']['InstanceType'] = profiles['frontend']['size']
      lc_fe['LaunchConfig']['Properties']['SecurityGroups'] = [{ 'Ref' => 'ISGFrontend' }, {'Ref' => 'ISGSSH'}]
      lc_fe['LaunchConfig']['Properties']['UserData']['Fn::Base64']['Fn::Join'][1] = script

      lc_be = JSON::parse(File.read(File.join('vendor', 'aws', 'cloudformation', 'resources', 'launch_config.json')))
      lc_be['LaunchConfig']['Properties']['ImageId'] = { 'Ref' => 'ImageId' }
      lc_be['LaunchConfig']['Properties']['InstanceType'] = profiles['backend']['size']
      lc_be['LaunchConfig']['Properties']['SecurityGroups'] = [{ 'Ref' => 'ISGBackend' }, {'Ref' => 'ISGSSH'}]
      lc_be['LaunchConfig']['Properties']['UserData']['Fn::Base64']['Fn::Join'][1] = script

      ## Frontend.
      asg_fe = get_tpl('resources', 'asg', 'ASG')
      asg_fe['ASG']['Properties']['MinSize'] = profiles['frontend']['min']
      asg_fe['ASG']['Properties']['Tags'] = [{ 'Key' => 'Name', 'Value' => format('fe-%s', @cfg['version']), 'PropagateAtLaunch' => true }]
      asg_fe['ASG']['Properties']['MaxSize'] = profiles['frontend']['max']
      asg_fe['ASG']['Properties']['LoadBalancerNames'][0]['Ref'] = 'ELBFrontend'
      asg_fe['ASG']['Properties']['LaunchConfigurationName']['Ref'] = 'LCFrontend'

      ## Backend.
      asg_be = get_tpl('resources', 'asg', 'ASG')
      asg_be['ASG']['Properties']['Tags'] = [{ 'Key' => 'Name', 'Value' => format('be-%s', @cfg['version']), 'PropagateAtLaunch' => true}]
      asg_be['ASG']['Properties']['MinSize'] = profiles['backend']['min']
      asg_be['ASG']['Properties']['MaxSize'] = profiles['backend']['max']
      asg_be['ASG']['Properties']['LoadBalancerNames'][0]['Ref'] = 'ELBBackend'
      asg_be['ASG']['Properties']['LaunchConfigurationName']['Ref'] = 'LCBackend'

      isg_fe = JSON::parse(File.read(File.join('vendor', 'aws', 'cloudformation', 'resources', 'isg.json')))
      isg_fe["InstanceSecurityGroup"]["Properties"]["GroupDescription"] = "Allow traffic in from the world on default web port."
      isg_fe["InstanceSecurityGroup"]["Properties"]["VpcId"] = { "Ref" => "VPCId" }
      isg_fe["InstanceSecurityGroup"]["Properties"]['SecurityGroupIngress'] = [{
        'CidrIp' => '0.0.0.0/0',
        'ToPort' => '80',
        'FromPort' => '80',
        'IpProtocol' => 'tcp'
      },{
        'CidrIp' => '0.0.0.0/0',
        'ToPort' => '443',
        'FromPort' => '443',
        'IpProtocol' => 'tcp'
      }]

      isg_be = JSON::parse(File.read(File.join('vendor', 'aws', 'cloudformation', 'resources', 'isg.json')))
      isg_be['InstanceSecurityGroup']['Properties']['GroupDescription'] = 'Only allow traffic from the cool kids in the be group.'
      isg_be['InstanceSecurityGroup']['Properties']['VpcId'] = { 'Ref' => 'VPCId' }
      isg_be['InstanceSecurityGroup']['Properties']['SecurityGroupIngress'] = [{
        "ToPort" => "8080",
        "FromPort" => "8080",
        "IpProtocol" => "tcp",
        "SourceSecurityGroupId" => { "Ref" => "ISGFrontend" }
        #"SourceSecurityGroupOwnerId" => {"Fn::GetAtt" => ["ELBFrontend", "SourceSecurityGroup.OwnerAlias"]}
      }]

      isg_ssh = JSON::parse(File.read(File.join('vendor', 'aws', 'cloudformation', 'resources', 'isg.json')))
      isg_ssh["InstanceSecurityGroup"]["Properties"]["VpcId"] = { "Ref" => "VPCId" }
      isg_ssh["InstanceSecurityGroup"]["Properties"]["GroupDescription"] = "SSH access from within the VPN only."
      isg_ssh["InstanceSecurityGroup"]["Properties"]['SecurityGroupIngress'] = [{
        "CidrIp" => { "Fn::FindInMap" => [ "SubnetConfig", "VPC", "CIDR" ]},
        "ToPort" => "22",
        "FromPort" => "22",
        "IpProtocol" => "tcp"
      }]

      data = {
        'ASGFrontend' => asg_fe["ASG"],
        'ASGBackend' => asg_be["ASG"],

        'ELBFrontend' => elb_fe['ELB'],
        'ELBBackend' => elb_be['ELB'],

        'LCFrontend' => lc_fe['LaunchConfig'],
        'LCBackend' => lc_be['LaunchConfig'],

        'ISGFrontend' => isg_fe['InstanceSecurityGroup'],
        'ISGBackend' => isg_be['InstanceSecurityGroup'],
        'ISGSSH' => isg_ssh['InstanceSecurityGroup']
      }.merge(iam)

      data
    end

  end
end
