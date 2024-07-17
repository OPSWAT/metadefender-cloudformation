# metadefender-cloudformation

### MetaDefender CloudFormation 
CloudFormation Templates to generate all resources needed to run the MetaDefender AMI. 

##### Notice:
IAM roles are build in order to:
- allow EC2 instance to update lambda function
- invoke the DeactivateLambda function execution

### CloudFormation Scripts

#### [Stand-alone MetaDefender Core](cloudformation/MetaDefenderWindows.template)
Launches a MetaDefender Core instance using a predefined AMI.
Applies the license keys and generates the additional resource (DeactivateLambda, DeactivateEventRule, IAM Profile, SG, etc.)

#### [Distributed Environment](cloudformation/MetaDefenderWindowsCM2AZ.template)
VPC:
- Creates a public subnet and 2 private subnets in 2 different AZs.

EC2:
- Launches 2 instances of MetaDefender Core
  - Each instance is deployed in a separated AZ, in one of the new created private subnets
- Launches OPSWAT Central Management in the public subnet
  - Activates Central Management and registers the 2 instances of MetaDefender Core
  - Retrieves all the engines and workflows

#### [Autoscaling](cloudformation/MetaDefenderWindowsAutoscaling.template)
VPC:
- Creates public and private subnets
  - Based on [quickstart-aws-vpc](https://github.com/aws-quickstart/quickstart-aws-vpc "Quicstart AWS VPC")

EC2:
- Launches OPSWAT Central Management in the public subnet
  - Activates Central Management
  - Retrieves all the engines and workflows

Autoscaling Group:
- Launches 1 instance of MetaDefender Core
  - Activates the product
  - Attaches it to OPSWAT Central Management
  - Adds it to ELB
- CPU High/Low alerts defined to scale up or down the deployment

ELB:
- Load balances all active MetaDefender Core instances
  - Sticky session is enabled


### Execution Flow
The predefined flow:
- EC2 instance has EC2UserData enabled and the boot script will:
  - Change password from default to instanceId at first run
  - Activate the product at each run
  - Update Lambda environment variables with the new deploymentId
  - Update event rule to trigger lambda function only for the generated EC2 instance
- Lambda
  - Expects the activation key and deploymentId to be provided as environment variables
  - Calls MetaDefender Activation Server's Deactivate API

##### Notice:
1. The AMI used for this script has MetaDefender running on the default port (8008).
2. All the used EC2UserData scripts are defined inline in the CloudFormation template for visibility. The scripts are also available as shell/Powershell separately.

## Additional Resources
In the *AWS CloudFormation User Guide*, you can view more information about the following topics:

- Learn how to use templates to create AWS CloudFormation stacks using the [AWS Management Console](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stack.html) or [AWS Command Line Interface (AWS CLI)](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-cli-creating-stack.html).
- To view all the supported AWS resources and their properties, see the [Template Reference](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html).

## Support

For specific product-related questions or issues please contact [support](https://www.opswat.com/support).

## License

[MIT](https://github.com/OPSWAT/metadefender-cloudformation/blob/master/LICENSE)
