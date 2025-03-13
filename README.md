# graph-agent-devops

Repository for reusable "simple" devops for the graph agent.

## Overview (what is this?)

The goal of this devops setup is to:

- Create a centralized and "sharable" description of machines and
  related services in AWS.
- Have this shared description be the mechanism for change in AWS.
- Create an environment and set of tools to manipulate this
  description, which is then relfected in the machines and services
  available in AWS.

In other words: you are creating a devops envirnment, "joining" a
shared workspace, then adding and removing machines, storage, and
networks in this shared workspace.

Currently, when using this devops setup, you are manipulating the
following things in AWS as a unit:

- an EC2 instance
- an EBS (disk for EC2 instances)
- an elastic IP address
- a public DNS entry pointing to the instance above w/EIP
- a dynamic security group (using default VPC, etc.)
- a dynamic key pair

## Prerequisites:

- Docker

**NOTE**: we have a docker-based environment with all these tools installed.

### Gather _your_ AWS credentials

Your (personal developer) AWS credentials are used by Terraform to provision the AWS instance and by the provisioned instance to access the certificate store and the S3 buckets used to store Apache logs. These are your personal AWS credentials and should have been appropriately created to give you these permissions.

**NOTE**: specifically, you will need to supply an `aws_access_key_id` and `aws_secret_access_key`. These will be marked with `REPLACE_ME` in the `ga-aws-credentials.sample` file farther down.

### SSH Keys

The keys we'll be using can be found in the shared SpiderOak store. If you don't know what this is, ask @kltm.

For testing purposes you can use your own ssh keys. But for production please ask for the graph agent ssh keys. The names will be:

```
ga-ssh.pub
ga-ssh
```

## Configuring and deploying EC2 _instances_ (and halo services)

1. Spin up the provided dockerized development environment:

```bash
docker rm ga-dev || true
docker run --name ga-dev -it geneontology/go-devops-base:tools-jammy-0.4.4 /bin/bash
```

These next commands are from _within_ the docker image:

```bash
cd /tmp
git clone https://github.com/monarch-initiative/graph-agent-devops.git
cd graph-agent-devops/provision
```

2. Copy in SSH keys

From _outside_ the docker image, copy the ssh keys from your docker host into the running docker image, in `/tmp`:

```bash
docker cp ga-ssh ga-dev:/tmp
docker cp ga-ssh.pub ga-dev:/tmp
```

You should now have the following in your image:

```bash
/tmp/ga-ssh
/tmp/ga-ssh.pub
```

Make sure they have the right perms to be used _within_ in the docker image:

```bash
chmod 600 /tmp/ga-ssh*
```

3. Establish the AWS credential files

All commands here on out will be _within_ the devops docker image, within the `/tmp/graph-agent-devops/provision` directory.

Copy and modify the AWS credential file to the default location `/tmp/ga-aws-credentials`.

```bash
cp production/ga-aws-credentials.sample /tmp/ga-aws-credentials
```

Add your personal dev keys into the file; update the `aws_access_key_id` and `aws_secret_access_key`:

```bash
emacs /tmp/ga-aws-credentials
```

4. Initialize the S3 Terraform backend:

"Initializing" a Terraform backend connects your local Terraform instantiation to a workspace backend; we are using S3 as the shared workspace backend (Terraform has others as well). This workspace backend will contain information on EC2 instances, network info, etc.; you (and other developers in the future) can discover and manipulate these states, bringing servers and services up and down in a shared and coordinated way. These Terraform backends are an arbitrary bundle and can be grouped as needed. In general, the production systems should all use the same pre-coordinated workspace, but you may create new ones for experimentation, etc.

For our current purposes, we will use a shared workspace backend with the name `ga-workspace`.

```bash
cp ./production/backend.tf.sample ./aws/backend.tf
```

This should be pre-filled as `ga-workspace`, but can be changed for reasons listed above.

```bash
emacs ./aws/backend.tf
```

Use the AWS CLI to make sure you have access to the Terraform S3 backend bucket:

```bash
export AWS_SHARED_CREDENTIALS_FILE=/tmp/ga-aws-credentials
```

Check credentials with a test connection to the S3 workspace backend
bucket.

```bash
aws s3 ls s3://ga-workspace
```

Proceed with Terraform initialization; if it doesn't work, we fail):

```bash
go-deploy -init --working-directory aws -verbose
```

Use these commands to figure out the name of existing workspaces, if any. If following these instructions, the names should have the pattern `ga-production-YYYY-MM-DD` or `default`.

```bash
go-deploy --working-directory aws -list-workspaces -verbose
```

5. Provision new instance on AWS, for potential production use:

These next few commands will setup creating a (new) production workspace using the following namespace pattern `ga-production-YYYY-MM-DD`; e.g.: `ga-production-2025-03-03`:

```bash
cp ./production/config-instance.yaml.sample config-instance.yaml
```

Replace the two instances of REPLACE\_ME\_WITH\_DATE with today's date (e.g. 2025-03-04); giving e.g.: `ga-production-2025-03-03`.

As well, verify the location of the SSH keys for your AWS instance:
`/tmp/ga-ssh`.


```bash
emacs config-instance.yaml
```

If you want to change the size of the machine (`instance_type`) or the size of the attached storage (`disk_size`), AMI, this is the time/place to do it.

Technically optional; verify the location of the public ssh key in `aws/main.tf`

```bash
emacs aws/main.tf
```

6. Test the deployment

For the next command, `REPLACE_ME_WITH_DATE` should be something like YYYY-MM-DD; giving a final full workspace name of something like `ga-production-2025-03-03`.

Test configuration:

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -dry-run --conf config-instance.yaml
```

7. Deploy

For the next command, `REPLACE_ME_WITH_DATE` should be something like YYYY-MM-DD; giving a final full workspace name of something like `ga-production-2025-03-03`.

Deploy command:

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose --conf config-instance.yaml
```

## Checking the deployment

For the next commands, `REPLACE_ME_WITH_DATE` should be something like YYYY-MM-DD; giving a final full workspace name of something like `ga-production-2025-03-03`.

Just to check, ask it to display what it just did (display the Terraform state):

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -show
```

This will dump out the changes/current state of the workspace we created.

Finally, just show the IP address of the AWS instance:

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -output
```

Access graph-agent-devops instance from the CLI by ssh'ing into the newly provisioned EC2 instance:

```bash
ssh -i /tmp/ga-ssh ubuntu@IP_ADDRESS
```

## Software installation

```bash
cd ../ansible
```

In `hosts`, replace `-REPLACE_ME_WITH_IP` with the IP address of your new instalce from above.

```bash
emacs hosts
```

Setup software with:

```bash
ansible-playbook mongo-setup-for-agent.yaml --inventory=hosts --private-key="/tmp/ga-ssh"
```

## Troubleshooting

These commands will produce an IP address in the resulting `inventory.json` file.
The previous command creates Terraform "tfvars". These variables override the variables in `aws/main.tf`

If you need to check what you have just done, here are some helpful Terraform commands:

```bash
cat ga-production-REPLACE_ME_WITH_DATE.tfvars.json
```

The previous command creates an ansible inventory file.
```bash
cat ga-production-REPLACE_ME_WITH_DATE-inventory.cfg
```

Useful Terraform commands to check what you have just done

```bash
terraform -chdir=aws workspace show   # current terraform workspace
terraform -chdir=aws show             # current state deployed ...
terraform -chdir=aws output           # shows public ip of aws instance
```

## Destroying instance and other destructive things

### Option 1: use tool

Destroy using tool: make sure you point to the correct workspace before destroying the stack by using the -show command or the -output command.

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -destroy
```

### Option 2: manual

Destroy manually: make sure you point to the correct workspace before destroying the stack.

```bash
terraform -chdir=aws workspace list
terraform -chdir=aws workspace show # shows the name of the current workspace
terraform -chdir=aws show           # shows the state you are about to destroy
terraform -chdir=aws destroy        # You would need to type Yes to approve.
```

Now delete the workspace.

```bash
terraform -chdir=aws workspace select default # change to default workspace--cannot delete workspace that you are "in"
terraform -chdir=aws workspace delete ga-production-YYYY-MM-DD
```
