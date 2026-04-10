# GH CLI
. "${HOME}/.env"

function clone_topic(){
  local topic="$1"
  local owner="$2"
  mkdir $topic
  cd $topic
  repos=($(gh repo list $owner --topic $topic --json nameWithOwner -q '.[] | .nameWithOwner'))
  for repo in $repos; do
    echo $repo
    gh repo clone $repo &
  done
  wait
}

# APPSSO
function sso_reset(){
  local pid=$(ps -eaf | grep AppSSOAgent | grep -v grep | awk '{print $2}')
  kill -9 $pid
  app-sso -d "${ssoDomain}"
}
# AWS ECR
function ecrpush(){
  local aws_region="${AWS_REGION}"
  local image="${1}"
  docker push "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${aws_region}.amazonaws.com/${image}"
}

function ecrpull(){
  local aws_region="${AWS_REGION}"
  local image="${1}"
  docker pull "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.${aws_region}.amazonaws.com/${image}"
}

#IPA
function ipajoin(){
  local env="${1}"
  ipa-client-install --domain="${env}.${domain}" --realm="${env}.${domain}^^" -p $2 -W --server=idm."${env}.${domain}" --force-join --mkhomedir
}

# AWS IAM
function aws_assume_role(){
	unset AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID

	local ROLE_NAME="$1"
	local ACCOUNT_ID="$(aws sts get-caller-identity --output text --query Account)"
	local TAIL="$(echo $RANDOM | md5sum | head -c 5)"

	local tokens=$(aws sts assume-role --role-arn arn:${aws_partition}:iam::${ACCOUNT_ID}:role/project/${ROLE_NAME} --role-session-name testing-${TAIL})

	local secret=$(echo -- "$tokens" | sed -n 's!.*"SecretAccessKey": "\(.*\)".*!\1!p')
	local session=$(echo -- "$tokens" | sed -n 's!.*"SessionToken": "\(.*\)".*!\1!p')
	local access=$(echo -- "$tokens" | sed -n 's!.*"AccessKeyId": "\(.*\)".*!\1!p')
	local expire=$(echo -- "$tokens" | sed -n 's!.*"Expiration": "\(.*\)".*!\1!p')

	export AWS_SESSION_TOKEN=$session
	export AWS_SECRET_ACCESS_KEY=$secret
	export AWS_ACCESS_KEY_ID=$access

	aws sts get-caller-identity
}

function aws_unassume_role(){
	unset AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID
}

#AWS secrets
function asec(){
  local name="${1}"
  local key="${2}"
  if ! [[ -x $(echo ${2}) ]]; then
    aws secretsmanager get-secret-value --secret-id $1 --output text --query 'SecretString' | jq -r .
  else
    aws secretsmanager get-secret-value --secret-id project-bip-platform/shared-secrets --output text --query 'SecretString' | jq -r --arg $2 $2 '.["${2}"]'
  fi
}

#AWS SSM
function ssm_connect(){
  local NAME="$1"

  local id=$(aws ec2 describe-instances --filter "Name=tag:Name,Values=[${NAME}]" --query "Reservations[].Instances[].InstanceId" --output text)

  aws ssm start-session --target=$id
}

#AWS EC2
function ec2_list(){
  local TAG_KEY="$1"
  local TAG_VALUES="$2"

  aws ec2 describe-instances --filter "Name=tag:${TAG_KEY},Values=[${TAG_VALUES}]" --query 'Reservations[].Instances[].[ [Tags[?Key==`Name`].Value][0][0],PrivateIpAddress,InstanceId,State[?Name==`Running`].Value[0]]' --output table
}
function ec2_instances(){
  args='
  Reservations[*].Instances[*].{
  Name: [Tags[?Key==`Name`].Value][0][0],
  IP: PrivateIpAddress,
  ID: InstanceId,
  State: State.Name,
  ApplicationID: [Tags[?Key==`ApplicationID`].Value][0][0],
  ProductLine: [Tags[?Key==`ProductLine`].Value][0][0],
  Product: [Tags[?Key==`Product`].Value][0][0]}
  '
  query=$(printf '%s' "$args")
  echo $query
  aws ec2 describe-instances \
    --query ${query} \
    --output json | jq -r 'map(.[]) | (.[0] | to_entries | map(.key)), (.[] | [.[]]) | @csv'
}

function ec2_subnet_list(){
  aws ec2 describe-subnets | jq -r '.Subnets[] | {id: .SubnetId, name: .Tags | map(select(.Key == "Name")), cidr: .CidrBlock}'
}

function rds_dbs() {
  account=`aws iam list-account-aliases --query 'AccountAliases' --output text`
  aws rds describe-db-instances --query 'DBInstances[]' | jq -r 'map({DBInstanceIdentifier: .DBInstanceIdentifier, DBInstanceClass: .DBInstanceClass, MultiAZ: .MultiAZ, LicenseModel: .LicenseModel, DBName: .DBName, Engine: .Engine, EngineVersion: .EngineVersion}) | (.[0] | to_entries | map(.key)), (.[] | [.[]]) | @csv'
}

# AWS EKS
function eks_ls(){
  local CLUSTERS=($(aws eks list-clusters --query "clusters[]" --output text))
  for id in $CLUSTERS; do
    aws eks describe-cluster --name $id --query 'cluster.{Name: name, StateKey: tags.state_key}' --output text | awk -F'/' '{print $1}';
  done
}

function eks_login(){
  local clusterid="$1"
  local alias="$(echo $clusterid | cut -d'/' -f 2)"
  aws eks update-kubeconfig --name $clusterid --alias $alias
}

#AWS SSM
function ssm_connect(){
  local NAME="$1"
  local id=$(aws ec2 describe-instances --filter "Name=tag:Name,Values=[${NAME}]" --query "Reservations[].Instances[].InstanceId" --output text)
  aws ssm start-session --target=$id
}

function ssm_node(){
  local NAME="$1"
  local id=$(kubectl get node ${NAME} -o json | jq -r '.spec | .providerID' | cut -d '/' -f 5)
  aws ssm start-session --target=$id
}
#AWS EC2
function ec2_list(){
  local TAG_KEY="$1"
  local TAG_VALUES="$2"
  aws ec2 describe-instances --filter "Name=tag:${TAG_KEY},Values=[${TAG_VALUES}]" --query 'Reservations[].Instances[].[ [Tags[?Key==`Name`].Value][0][0],PrivateIpAddress,InstanceId,LaunchTime]' --output table
}

function ec2_subnet_list(){
  aws ec2 describe-subnets | jq -r '.Subnets[] | {id: .SubnetId, name: .Tags | map(select(.Key == "Name"))}'
}

function ec2_ami(){
  local NAME_TAG="$1"
  aws ec2 describe-images --filter "Name=tag:Name,Values=[?contains(@, '${NAME_TAG}']" --output json --query 'Images[].{name: Name, id: ImageId}'
}

function ec2_vpc_ls(){
  local VPC_NAME_FILTER="$1"
  aws ec2 describe-vpcs --filters "Name=tag:Name,Values=['${VPC_NAME_FILTER}']" --query "Vpcs[].{Name:Tags[?Key=='Name']|[0].Value, ID:VpcId}" --output table
}

function ec2_free_eni(){
  local VPCID="$1"
  aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=['${VPCID}']" --query 'sort_by(NetworkInterfaces, &SubnetId)[].{Requester: RequesterId, Status: Status, Description: Description, Subnet: SubnetId}' --output table
}


# GH
function gh_latestTag() {
  owner="${1}"
  repo="${2}"
  gh api graphql -q '.data | .repository | .refs | .edges[] | .node | .name' -F owner="${owner}" -F name="${repo}" -f query='
  query($name: String!, $owner: String!) {
    repository(owner: $owner, name: $name) {
      refs(refPrefix: "refs/tags/", first: 1, orderBy: {field: TAG_COMMIT_DATE, direction: DESC}) {
        edges {
          node {
            name
          }
        }
      }
    }
  }'
}

# Kubectl
function k_node_drain() {
  local node=${1}
  k drain --force --ignore-daemonsets --delete-emptydir-data --grace-period -1 --timeout 0s $node
}

function k_node_pods() {
  local node=${1}
  k get pods -A --field-selector spec.nodeName=$node
}

function k_node_ssm() {
  local nodeName="${1}"
  local instanceId=`k get node ${nodeName} -o json | jq -r '.spec.providerID | split("/")[4]'`
  aws ssm start-session --target=${instanceId}
}

function ssm_tunnel() {
  local tagName=${1}
  instanceid=`aws ec2 describe-instances --filter "Name=tag:Name,Values=['${1}']" --query 'Reservations[].Instances[].InstanceId' --output text`
  aws ssm start-session --target $instanceid --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["443"],"localPortNumber":["11110"]}' &
}

function adfs_login(){
  local profile="${1}"
  local region="${2}"
  export username="${adfs_username}"
  export password=$(security find-generic-password -s cyberark -w)
  aws-adfs login --profile ${profile} --env
  # aws-adfs login --adfs-host=prod.adfs.federation.va.gov --provider-id urn:amazon:webservices:govcloud --region us-gov-west-1 --no-ssl-verification --assertfile $SAML_DEST_FILE --profile ${1}
  # setting profile var
  # exporting AWS profile vars
  export AWS_REGION=${region}
  export AWS_DEFAULT_REGION=${region}
  export AWS_PROFILE=${profile}
  export AWS_DEFAULT_PROFILE=${profile}
  unset username
  unset password
}

function cluster_scale_up() {
  clusterid="${1}"
  alias="$(echo $clusterid | cut -d'/' -f 2)"
  aws eks update-kubeconfig --name $clusterid --region $2 --alias $alias
  groups_list=($(aws eks list-nodegroups --cluster-name ${clusterid} --query 'nodegroups' --output text))
  echo "$groups_list"
  for x in ${groups_list}; do
      aws eks update-nodegroup-config --cluster-name ${clusterid} --nodegroup-name ${x} \
      --scaling-config minSize=0,maxSize=5,desiredSize=1
  done
  kubectl scale statefulset argocd-application-controller -n argocd --replicas=1;
  kubectl scale deploy confluent-operator -n confluent --replicas=1 || true;
}

function vault_login(){
  local VAULT_ADDR
  export VAULT_ADDR="https://${1}"
}

# launch kubernetes tool in browser
function launch() {
    local tool=$1

    # Extract cluster_id from the current kubectl context
    cluster_id=$(kubectl config current-context)

    # Ensure cluster_id is not empty
    if [[ -z "$cluster_id" ]]; then
        echo "Error: Couldn't determine cluster_id. Either provide it or ensure kubectl context is set."
        return 1
    fi

    # Check for special handling of tools
    if [[ "$tool" == "argocd" ]]; then
        kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | pbcopy
        echo "Initial admin password for ArgoCD has been copied to clipboard."
    elif [[ "$tool" == "argo" ]]; then
        kubectl -n argocd-tenant get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | pbcopy
        echo "Initial admin password for Argo has been copied to clipboard."
    elif [[ "$tool == "harness" ]]; then
    fi

    # Construct the URL
    local url="https://$tool.$cluster_id.eks.local/"

    # Echo confirmation message
    echo "Opening $tool on $cluster_id.eks.local..."

    # Launch the URL in Chrome
    open -a "Google Chrome" $url
}

function gh_run(){
  local workflow="${1}"
  local ref="${2}"
  gh workflow run $workflow \
    --ref "${ref}" \
    -f "github_environment=${3}" \
    -f "input_image_tag=${4}" \
    -f "just_recipe=${5}" \
    -f "terragrunt_directory=${6}" \
    -f "just_flags=--terragrunt-ignore-dependency-errors" \
    -f "target_long_lived=CONFIRM"
}
