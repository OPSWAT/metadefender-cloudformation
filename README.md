# metadefender-cloudformation

### MetaDefender CloudFormation 
Draft script to generate all resources needed to run the MetaDefender AMI. 

##### Notice:
IAM roles are build in order to:
- allow EC2 instance to update lambda function
- invoke DeactivateLambda function execution


### Execution Flow
The predefined flow:
- EC2 instance has EC2UserData enabled and the boot script will:
  - Change password from default to instanceId at first run
  - Activate the product at each run
  - Update Lambda function with the new deploymentId
  - Update event rule to trigger lambda function only for the generated EC2 instance
- Lambda
  - Expects the activation key and deploymentId to be provided as environment variables
  - Calls MetaDefender Activation Server's Deactivate API 

##### Notice:
The AMI used for this script has MetaDefender running on the default port (8008). 

