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
- a public DNS entry pointing to the instance above
- TODO

## Prerequisites:

- Docker

**NOTE**: we have a docker-based environment with all these tools installed.

## Configuring and deploying EC2 _instances_:

From step "5", all steps will be completed in a dockerized development environment. The first two commands are for preparation, "3" and "4" establish this repo and ssh credentials in the docker environment.

1. Gather _your_ AWS credentials:

Your (personal developer) AWS credentials are used by Terraform to provision the AWS instance and by the provisioned instance to access the certificate store and the S3 buckets used to store Apache logs. These are your personal AWS credentials and should have been appropriately created to give you these permissions.

**NOTE**: specifically, you will need to supply an `aws_access_key_id` and `aws_secret_access_key`. These will be marked with `REPLACE_ME` in the `ga-aws-credentials.sample` file farther down.

2. SSH Keys

The keys we'll be using can be found in the shared SpiderOak store. If you don't know what this is, ask @kltm.

For testing purposes you can use your own ssh keys. But for production please ask for the graph agent ssh keys. The names will be:

```
ga-ssh.pub
ga-ssh
```

3. Spin up the provided dockerized development environment:

```bash
docker rm ga-dev || true
docker run --name ga-dev -it geneontology/go-devops-base:tools-jammy-0.4.4  /bin/bash
cd /tmp
git clone https://github.com/monarch-initiative/graph-agent-devops.git
cd graph-agent-devops/provision
```

4. Copy in SSH keys

Copy the ssh keys from your docker host into the running docker image, in `/tmp`:

```
docker cp ga-ssh ga-dev:/tmp
docker cp ga-ssh.pub ga-dev:/tmp
```
You should now have the following in your image:
```
/tmp/ga-ssh
/tmp/ga-ssh.pub
```
Make sure they have the right perms to be used in the docker image:
```
chmod 600 /tmp/ga-ssh*
```

5. Establish the AWS credential files

Within the running image, copy and modify the AWS credential file to the default location `/tmp/ga-aws-credentials`.

```bash
cp production/ga-aws-credentials.sample /tmp/ga-aws-credentials
```
Add your personal dev keys into the file; update the `aws_access_key_id` and `aws_secret_access_key`:
```
emacs /tmp/ga-aws-credentials
```

6. Initialize the S3 Terraform backend:

"Initializing" a Terraform backend connects your local Terraform instantiation to a workspace; we are using S3 as the shared workspace medium (Terraform has others as well). This workspace will contain information on EC2 instances, network info, etc.; you (and other developers in the future) can discover and manipulate these states, bringing servers and services up and down in a shared and coordinated way. These Terraform backends are an arbitrary bundle and can be grouped as needed. In general, the production systems should all use the same pre-coordinated workspace, but you may create new ones for experimentation, etc.

Typically, the name of the workspace is `ga-workspace-` + the name of the service; i.e. `ga-workspace` for the use case here.

```bash
cp ./production/backend.tf.sample ./aws/backend.tf
```

Replace the REPLACE\_ME\_GA\_S3\_STATE\_STORE with the appropriate workspace name: `ga-workspace`.

```bash
emacs ./aws/backend.tf
```

Use the AWS CLI to make sure you have access to the terraform s3 backend bucket

```bash
export AWS_SHARED_CREDENTIALS_FILE=/tmp/ga-aws-credentials
```

Check connection to S3 "workspace" bucket.

```bash
aws s3 ls s3://ga-workspace
```

Proceed with Terraform initialization; if it doesn't work, we fail):

```bash
go-deploy -init --working-directory aws -verbose
```

Use these commands to figure out the name of an existing workspace if any. The names should have a pattern `ga-production-YYYY-MM-DD` or `default`.

```bash
go-deploy --working-directory aws -list-workspaces -verbose
```

7. Provision new instance on AWS, for potential production use:

Create a (new) production workspace using the following namespace pattern `ga-production-YYYY-MM-DD`; e.g.: `ga-production-2025-03-03`:

```bash
cp ./production/config-instance.yaml.sample config-instance.yaml
```

Verify the location of the SSH keys for your AWS instance: /tmp/ga-ssh

```bash
emacs config-instance.yaml
```

Technically optional; verify the location of the public ssh key in `aws/main.tf`

```bash
emacs aws/main.tf
```

Next, give a human-readable string for the instance/tags/name (EC2 instance `Name` tag) for REPLACE\_ME\_WITH\_DATE, make it the same at the namespace pattern above; i.e. `ga-production-2035-03-03`:

You will also need to change `dns_record_name` in a similar way.

Finally, if you want to change the size of the machine (`instance_type`) or the size of the attached storage (`disk_size`), this is the time/place to do it.

```
emacs config-instance.yaml
```

8. Test the deployment

For the next command, `REPLACE_ME_WITH_DATE` should be something like YYYY-MM-DD; giving a final full workspace name of something like `ga-production-2025-03-03`.

Test configuration:

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -dry-run --conf config-instance.yaml
```

9. Deploy

Deploy command:

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose --conf config-instance.yaml
```

10. Checking what we have done

Just to check, ask it to display what it just did (display the Terraform state):
```
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -show
```

Finally, just show the IP address of the AWS instance:
```
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -output
```

## Troubleshooting:

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

Access graph-agent-devops instance from the CLI by ssh'ing into the newly provisioned EC2 instance:

```bash
ssh -i /tmp/ga-ssh ubuntu@IP_ADDRESS
```

## Destroy instance and other destructive things:

Destroy using tool: make sure you point to the correct workspace before destroying the stack by using the -show command or the -output command.

```bash
go-deploy --workspace ga-production-REPLACE_ME_WITH_DATE --working-directory aws -verbose -destroy
```

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
