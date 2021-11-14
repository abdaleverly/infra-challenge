# EC2 Webserver powered by CICD pipeline
![Infrastructure diagram](images/infrastructure.png)

This solution provisions a website hosted in AWS, that is powered by a GitHub repository. As application code is pushed to the remote git repository, the pipeline is triggered. The pipeline takes code from the source and passes it through a build stage and artifacts are generated. Finally a deploy stage takes deploys the build artifact to an ec2 instance opened to http traffic.

### Resources provisioned
- VPC network
- Codepipeline
- CodeBuild
- CodeDeploy
- Codestar Connections (needs authorization to GitHub)
- EC2 attached with an Elastic IP and Security Group
- KMS key
- IAM roles, policies and profiles

## Prerequisites
- Configure awscli to your account
- Create an AWS S3 bucket to store backend state
- Terraform version 1.0
- GitHub Account hosting web code

## Customize your copy of the Infrastructure Code
Navigate to `backend.tf` and `variables.tf` file and customize your values.
```bash
### backend.tf 
terraform {
  backend "s3" {
    bucket = "${TF_S3_BACKEND_BUCKET_NAME}" # <-- update
    key    = "webserver" # <-- update
    region = "us-east-1" # <-- update
  }
}

### variable.tf
...
variable "stack_name" {
  default = "challenge" # <-- update
}
variable "github_org_name" {
  default = "" # <-- update
}
variable "github_app_repository_name" {
  default = "" # <-- update
}
```

To validate prerequisites, run
```bash
make init
```

## Provision and Setup the Infrastructure
To provision the resources, run
```bash
make build HTTP_CIDR=<Insert private cidr here>
```
> The web_endpoint may take ~2 minutes to be available directly after provisioning. You can check the endpoint by retrieving the `$ make get-web-endpoint` and pasting in a browser.

After all resources are provisioned for the first time, you will have to connect `AWS Codestar` to your GitHub account. 
1. Go to the codestar connections dashboard here - https://console.aws.amazon.com/codesuite/settings/connections
2. Choose the name of the pending connection you want to update. The **Update pending connection** button is enabled when you choose a connection with a *Pending* status
3. Click **Update pending connection**
4. For first time connections, authorize AWS Connector to GitHub
5. On the **Connect to GitHub** page, under GitHub apps, if you have already installed AWS Connector in GitHub apps, then choose your Github app id in search box and skip to the end. If this is your first time, click **Install a new app**.
6. Click **Install** when GitHub prompts you
7. The *Connect to GitHub* page, the connection ID will be available in the search, make sure its selected and click *Connect*

### Security Features Included
- SSH port is not open on the webserver security group. To gain ssh access to the server, Connect using SSM's Session Manager
- Pipeline and artifacts are encrypted with AWS KMS Customer Managed Key

## Smoke Test
To run smoke test to confirm app is deployed, run
```bash
make test

# If you want to check if a particular version is deployed, then
SHORT_HASH_OR_TAG=v1.0.0 make test
```
replace `v1.0` with git tag or short hash of released version

## Clean Up
To clean up resources
```bash
make clean HTTP_CIDR=<Insert private cidr here>
```

## Upcoming improvements
- Make webserver architecture highly available
- For reusability, refactor infastructure code into a module
- Secure website with SSL certificate terminated (preferably terminate on the Load Balancer)
- Reduce scope of IAM roles further
- Enable [github advanced security](https://docs.github.com/en/code-security/secret-scanning/configuring-secret-scanning-for-your-repositories) to scan repository for secrets and vulnerabilities
- Trigger a separate pipeline based on tagging to different environment (like production)
- Add test and security stage to the pipeline to run test on code and on the web endpoint