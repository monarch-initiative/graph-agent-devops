# graph-agent-devops

Repository for reusable "simple" devops for the graph agent.

## Prerequisites:

- Docker

**NOTE**: we have a docker-based environment with all these tools installed.

## Configuring and deploying EC2 _instances_:

From step "3", all steps will be completed in a dockerized development environment. The first two commands are for preparation.

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
Make sure they have the right perms to be used:
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

Typically, the name of the workspace is `ga-workspace-` + the name of the service; i.e. `ga-workspace-api` for the use case here.

```bash

cp ./production/backend.tf.sample ./aws/backend.tf

# Replace the REPLACE_ME_GOAPI_S3_STATE_STORE with the appropriate workspace (state store ~= workspace); so `ga-workspace-api`.
emacs ./aws/backend.tf

# Use the AWS CLI to make sure you have access to the terraform s3 backend bucket
export AWS_SHARED_CREDENTIALS_FILE=/tmp/ga-aws-credentials

# Check connection to S3 bucket.
aws s3 ls s3://ga-workspace-api

# Initialize (if it doesn't work, we fail):
ga-deploy -init --working-directory aws -verbose

# Use these commands to figure out the name of an existing workspace if any. The name should have a pattern `ga-api-production-YYYY-MM-DD`
ga-deploy --working-directory aws -list-workspaces -verbose
```

7. Provision new instance on AWS, for potential production use:

Create a (new) production workspace using the following namespace pattern `ga-api-production-YYYY-MM-DD`; e.g.: `ga-api-production-2023-01-30`:

```bash
cp ./production/config-instance.yaml.sample config-instance.yaml
emacs config-instance.yaml  # verify the location of the SSH keys for your AWS instance: /tmp/ga-ssh
emacs aws/main.tf # technically optional; verify the location of the public ssh key in `aws/main.tf`
```

As well, give a human-readable string for the instance/tags/name (EC2 instance name tag), make it the same at the namespace pattern above; i.e. `ga-api-production-2024-01-22`:

```
emacs config-instance.yaml
```

8. Test the deployment

`REPLACE_ME_WITH_S3_WORKSPACE_NAME` would be something like `ga-api-production-<TODAYS_DATE>`; i.e. `ga-api-production-2024-01-22`

```bash
ga-deploy --workspace REPLACE_ME_WITH_S3_WORKSPACE_NAME --working-directory aws -verbose -dry-run --conf config-instance.yaml
```

9. Deploy

Deploy command:
```bash
ga-deploy --workspace REPLACE_ME_WITH_S3_WORKSPACE_NAME --working-directory aws -verbose --conf config-instance.yaml
```

10. Checking what we have done

Just to check, ask it to display what it just did (display the Terraform state):
```
ga-deploy --workspace REPLACE_ME_WITH_S3_WORKSPACE_NAME --working-directory aws -verbose -show
```

Finally, just show the IP address of the AWS instance:
```
ga-deploy --workspace REPLACE_ME_WITH_S3_WORKSPACE_NAME --working-directory aws -verbose -output
```

**NOTE**: write down the IP address of the AWS instance that is created. This can also be found in `REPLACE_ME_WITH_S3_WORKSPACE_NAME.cfg` (e.g. ga-api-production-YYYY-MM-DD.cfg).

Useful details for troubleshooting:
These commands will produce an IP address in the resulting `inventory.json` file.
The previous command creates Terraform "tfvars". These variables override the variables in `aws/main.tf`

If you need to check what you have just done, here are some helpful Terraform commands:

```bash
cat REPLACE_ME_WITH_S3_WORKSPACE_NAME.tfvars.json # e.g, ga-api-production-YYYY-MM-DD.tfvars.json
```

The previous command creates an ansible inventory file.
```bash
cat REPLACE_ME_WITH_S3_WORKSPACE_NAME-inventory.cfg  # e.g, ga-api-production-YYYY-MM-DD-inventory
```

Useful Terraform commands to check what you have just done

```bash
terraform -chdir=aws workspace show   # current terraform workspace
terraform -chdir=aws show             # current state deployed ...
terraform -chdir=aws output           # shows public ip of aws instance
```

## Configuring and deploying software (grapg-agent-devops) _stack_:

These commands continue to be run in the dockerized development environment.

**POSSIBLE CUT START**
```bash
* replace "REPLACE_ME" values in config-instance.yaml for dns_record_name and dns_zone_id,
dns_zone_id should be "Z04640331A23NHVPCC784" and dns_record_name is the FQDN plus the REPLACE_ME_WITH_TERRAFORM_BACKEND, eg. api-production-2024-08-21.geneontology.org
* Location of SSH keys may need to be replaced after copying config-stack.yaml.sample
* S3 credentials are placed in a file using the format described above
* S3 uri if SSL is enabled. Location of SSL certs/key
* QoS mitigation if QoS is enabled
* Use the same workspace name as in the previous step
**POSSIBLE CUT END**

Let's ready the the instance, starting by editing the config:
```bash
cp ./production/config-stack.yaml.sample ./config-stack.yaml
emacs ./config-stack.yaml
```
Change these in emacs:
* `S3_BUCKET`: "ga-service-logs-api" (as above)
* `S3_SSL_CERTS_LOCATION`: "s3://ga-service-lockbox/geneontology.org.tar.gz"; this is generally of the form: ga-service-lockbox/_TLD_.tar.gz";
* `fastapi_host`: "api-test.geneontology.org"; (must be a FQDN)
* `fastapi_tag`: E.g. "0.2.0"; this should be the Dockerhub _tagged_ version of the API (which is how we deploy within the image), which is conincidentally the GitHub version of the API _sans the final "v"_. <- important point!

Finally, get ansible ready:
```
export ANSIBLE_HOST_KEY_CHECKING=False
````

Run the deployment of the stack within the instance:

```bash
ga-deploy --workspace REPLACE_ME_WITH_S3_WORKSPACE_NAME --working-directory aws -verbose --conf config-stack.yaml
```

## Testing deployment (within the dev image):

1. Access graph-agent-devops instance from the CLI by ssh'ing into the newly provisioned EC2 instance:
```
ssh -i /tmp/ga-ssh ubuntu@IP_ADDRESS
```

3. Access graph-agent-devops from a browser:

+We use health checks in the `docker-compose` file.+ (where to put this?)

Use the graph-agent-devops CNAME name. https://{fastapi_host}/docs

3. Debugging (in the AWS instance):

* Use -dry-run and copy and paste the command and execute it manually
* ssh to the machine; the username is ubuntu. Try using DNS names to make sure they are fine.

```bash
docker-compose -f stage_dir/docker-compose.yaml ps
docker-compose -f stage_dir/docker-compose.yaml down # whenever you make any changes
docker-compose -f stage_dir/docker-compose.yaml up -d
docker-compose -f stage_dir/docker-compose.yaml logs -f
```

4. Testing LogRotate:

```bash
docker exec -u 0 -it apache_fastapi bash # enter the container
cat /opt/credentials/s3cfg

echo $S3_BUCKET
aws s3 ls s3://$S3_BUCKET
logrotate -v -f /etc/logrotate.d/apache2 # Use -f option to force log rotation.
cat /tmp/logrotate-to-s3.log # make sure uploading to s3 was fine
```

5. Testing Health Check:

```sh
docker inspect --format "{{json .State.Health }}" graph-agent-devops
```


## Destroy Instance and other destructive things:

```bash
# Destroy Using Tool.
# Make sure you point to the correct workspace before destroying the stack by using the -show command or the -output command
ga-deploy --workspace REPLACE_ME_WITH_S3_WORKSPACE_NAME --working-directory aws -verbose -destroy
```

```bash
# Destroy Manually
# Make sure you point to the correct workspace before destroying the stack.

terraform -chdir=aws workspace list
terraform -chdir=aws workspace show # shows the name of the current workspace
terraform -chdir=aws show           # shows the state you are about to destroy
terraform -chdir=aws destroy        # You would need to type Yes to approve.

# Now delete the workspace.

terraform -chdir=aws workspace select default # change to default workspace
terraform -chdir=aws workspace delete <NAME_OF_WORKSPACE_THAT_IS_NOT_DEFAULT>  # delete workspace.
```

### Helpful commands for the docker container used as a development environment (ga-dev):

1. start the docker container `ga-dev` in interactive mode.

```bash
docker run --rm --name ga-dev -it geneontology/go-devops-base:tools-jammy-0.4.4  /bin/bash
```

In the command above we used the `--rm` option which means the container will be deleted when you exit.
If that is not the intent and you want to delete it later at your own convenience. Use the following `docker run` command.

```bash
docker run --name ga-dev -it geneontology/go-devops-base:tools-jammy-0.4.4  /bin/bash
```

2. To exit or stop the container:

```bash
docker stop ga-dev                   # stop container with the intent of restarting it. This is equivalent to `exit` inside the container.
docker start -ia ga-dev              # restart and attach to the container.
docker rm -f ga-dev                  # remove it for good.
```

3. Use `docker cp` to copy these credentials to /tmp:

```bash
docker cp /tmp/ga-aws-credentials ga-dev:/tmp/
docker cp /tmp/ga-ssh ga-dev:/tmp
docker cp /tmp/ga-ssh.pub ga-dev:/tmp
```

within the docker image:

```bash
chown root /tmp/ga-*
chgrp root /tmp/ga-*
chmod 400 /tmp/ga-ssh
```
