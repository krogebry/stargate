##
# Infrastructure things.
##

module Stargate
  class Monitoring < Stack
    def parameters
      data = {}
      ['ssh', 'chef', 'domain', 'keyname' ].each do |name|
        data.deep_merge!(get_tpl('parameters', name))
      end
      data
    end

    def params
      data = super

      base_ami_version = @cfg['environment']['aws']['cloudformation']['images']['krogebry-base-hvm']

      ami = find_ami( 'Name' => 'krogebry-base-hvm', 'Version' => base_ami_version )
      data['KeyName'] = @cfg['environment']['aws']['cloudformation']['key_name']
      data['ImageId'] = ami[0]['ImageId']

      data
    end

    def resources
      #defaults = super
      #defaults.deep_merge({"blah" => { "yada" => 1 }})

      script = [ "#!/bin/bash -xe\n",
        # "yum update -y aws-cfn-bootstrap\n".
        format("chef-solo -c /etc/chef/solo.rb -j /etc/chef/dna.json -E %s\n", @cfg["environment"]["name"])
        # "/opt/aws/bin/cfn-init -v ",
        # " --stack ", { "Ref" => "AWS::StackName" },
        # " --resource LaunchConfig ",
        # " --region ", { "Ref" => "AWS::Region" }, "\n",
        # "/opt/aws/bin/cfn-signal -e $? ",
        # " --stack ", { "Ref" => "AWS::StackName" },
        # " --resource WebServerGroup ",
        # " --region ", { "Ref" => "AWS::Region" }, "\n" 
      ]

      env_cfg = @cfg['environment']['aws']['cloudformation']
      profiles = env_cfg['profiles']
      zones = env_cfg['zones']
      pp zones

      vpc = get_tpl('resources', 'vpc')
      vpc['PublicSubnet']['Properties']['AvailabilityZone'] = zones['public']

      asg_bastion = get_tpl('resources', 'asg', 'ASG')
      asg_bastion['ASG']['Properties'].delete('LoadBalancerNames')
      asg_bastion['ASG']['Properties']['Tags'] = [{ 'Key' => 'Name', 'Value' => format('bastion-%s', @cfg['version']), 'PropagateAtLaunch' => true}]
      asg_bastion['ASG']['Properties']['MinSize'] = 1
      asg_bastion['ASG']['Properties']['VPCZoneIdentifier'] = [{'Ref' => 'PublicSubnet'}]
      asg_bastion['ASG']['Properties']['MaxSize'] = 1
      asg_bastion['ASG']['Properties']['AvailabilityZones'] = [zones['public']]
      asg_bastion['ASG']['Properties']['LaunchConfigurationName']['Ref'] = 'LC'
      
      isg_ssh = JSON::parse(File.read(File.join('vendor', 'aws', 'cloudformation', 'resources', 'isg.json')))
      isg_ssh = get_tpl('resources', 'isg', 'ISGSSH')
      isg_ssh["ISGSSH"]["Properties"]["GroupDescription"] = "SSH access from within the VPN only."
      isg_ssh["ISGSSH"]["Properties"]["VpcId"] = { "Ref" => "VPC" }
      isg_ssh["ISGSSH"]["Properties"]['SecurityGroupIngress'] = [{
        "CidrIp" => "0.0.0.0/0",
        "ToPort" => "22",
        "FromPort" => "22",
        "IpProtocol" => "tcp"
      }]

      lc_bastion = get_tpl('resources', 'launch_config', 'LC')
      lc_bastion['LC']['DependsOn'] = 'VPC'
      lc_bastion['LC']['Properties']['ImageId'] = { 'Ref' => 'ImageId' }
      lc_bastion['LC']['Properties']['InstanceType'] = 't2.micro'
      lc_bastion['LC']['Properties']['AssociatePublicIpAddress'] = true
      lc_bastion['LC']['Properties']['SecurityGroups'] = [{ 'Ref' => 'ISGSSH' }]
      lc_bastion['LC']['Properties']['UserData']['Fn::Base64']['Fn::Join'][1] = script

      vpc.merge(asg_bastion).merge(lc_bastion).merge(isg_ssh)
    end

  end
end
