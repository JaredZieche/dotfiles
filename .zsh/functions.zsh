# GH CLI
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
  app-sso -d resource.ds.bah.com
}
# AWS ECR
function ecrpush(){
  docker push "$(aws sts get-caller-identity --query Account --output text)".dkr.ecr.us-gov-west-1.amazonaws.com/"$1"
}

function ecrpull(){
  docker pull "$(aws sts get-caller-identity --query Account --output text)".dkr.ecr.us-gov-west-1.amazonaws.com/"$1"
}

#IPA
function ipajoin(){
  ipa-client-install --domain="$1".bip.va.gov --realm="$1^^".BIP.VA.GOV -p $2 -W --server=idm."$1".bip.va.gov --force-join --mkhomedir
}

# AWS IAM
function aws_assume_role(){
	unset AWS_SESSION_TOKEN AWS_SECRET_ACCESS_KEY AWS_ACCESS_KEY_ID

	local ROLE_NAME="$1"
	local ACCOUNT_ID="$(aws sts get-caller-identity --output text --query Account)"
	local TAIL="$(echo $RANDOM | md5sum | head -c 5)"

	local tokens=$(aws sts assume-role --role-arn arn:aws-us-gov:iam::${ACCOUNT_ID}:role/project/${ROLE_NAME} --role-session-name testing-${TAIL})

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

function ec2_subnet_list(){
  aws ec2 describe-subnets | jq -r '.Subnets[] | {id: .SubnetId, name: .Tags | map(select(.Key == "Name"))}'
}

# AWS EKS
function eks_ls(){
  local CLUSTER="$1"
  local CLUSTERS=($(aws eks list-clusters --query "clusters[?contains(@, '${CLUSTER}')]" --output text))
  for id in $CLUSTERS; do
    echo "${id}"
    echo "$(aws eks describe-cluster --name ${id} --query 'cluster.tags.state_key' --output text | cut -d '/' -f 1)"
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
