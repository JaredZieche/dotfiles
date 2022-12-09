# GH CLI
function clone_topic(){
  local topic="$1"
  local owner="department-of-veterans-affairs"
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
  local pid=$(ps -eaf | grep AppSSOAgent | grep -v grep | cut -d' ' -f 4)
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
  aws eks update-kubeconfig --name $clusterid
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
# Gangway
function gangway_new(){
    if [ -z "$1" ]; then
      echo "No cluster supplied. e.g: cluster_login dev8";
      return 1;
    fi;
    cluster=$1;
    urlgang=https://gangway.${cluster}.bip.va.gov;
    urldex=https://platform.${cluster}.bip.va.gov/oidc/${cluster};
    bipuser=$2;
    echo -n Password:
    read -s bippass
    echo
    req=`curl -k -s "$urlgang/login" -L -c temp.cj | sed -n 's:^.*form.*action="/oidc/dev/auth/ldap/login?back=.*state=\([^"]*\)".*$:\1:p'`;
    echo "${req}"
    curl -k -v "$urldex/auth/ldap?req=$req" -F "login=$bipuser" -F "password=$bippass";
    token=`curl -k "$urldex/approval?req=$req" -c temp.cj -b temp.cj -L -s | sed -n "s/.*--auth-provider-arg='id-token=\([^']*\)'$/\1/p"`;
    echo "${token}"
    curl -k "$urlgang/kubeconf" -b temp.cj --output ~/.kube/config -s;
    rm temp.cj;
}
function gangway_old(){
    if [ -z "$1" ]; then
      echo "No cluster supplied. e.g: cluster_login dev8";
      return 1;
    fi;
    cluster=$1;
    urlgang=https://gangway.${cluster}.bip.va.gov;
    urldex=https://dex.${cluster}.bip.va.gov;
    bipuser=$2;
    echo -n Password:
    read -s bippass
    echo
    req=`curl -k -s "$urlgang/login" -L -c temp.cj | sed -n 's:^.*form.*action="/auth/ldap?req=\([^"]*\)".*$:\1:p'`;
    curl -k "$urldex/auth/ldap?req=$req" -F "login=$bipuser" -F "password=$bippass" -s > /dev/null;
    token=`curl -k "$urldex/approval?req=$req" -c temp.cj -b temp.cj -L -s | sed -n "s/.*--auth-provider-arg='id-token=\([^']*\)'$/\1/p"`;
    curl -k "$urlgang/kubeconf" -b temp.cj --output ${KUBECONFIG} -s;
    rm temp.cj;
}
function adfs_login(){
  # ADFS Login Flow with PIV Card
  # Setup Instructions Here
  export COOKIE_JAR=~/.aws/cookies2.txt
  export OPENSSL_CONF=~/.config/openssl.conf
  export SAML_DEST_FILE=~/.aws/assertb64
  # Clear the cookie jar
  echo "Clearing cookie jar.."
  : > $COOKIE_JAR
  echo "Starting ADFS Login Flow.."
  # Start web flow by curling endpoint
  CLIENT_REQ=$(curl  -c $COOKIE_JAR "https://prod.adfs.federation.va.gov/adfs/ls/idpinitiatedsignon.aspx?loginToRp=urn:amazon.webservices" | sed -nE "s/.*client-request-id=(.*)\".*$/\1/p" | sort -u)
  echo "Client Request: ${CLIENT_REQ} .."

  echo "Logging in with PIV Card.."
  # Curl the Certificate Login Endpoint using PIV for auth
  curl -L -c $COOKIE_JAR -b $COOKIE_JAR \
  --key  'pkcs11:id=%01;type=private' \
  --cert 'pkcs11:id=%01;type=cert' \
  "https://prod.adfs.federation.va.gov:49443/adfs/ls/idpinitiatedsignon.aspx/?client-request-id=${CLIENT_REQ}" \
    -H 'Connection: keep-alive' \
    -H 'Pragma: no-cache' \
    -H 'Cache-Control: no-cache' \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H 'Origin: null' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.5112.101 Safari/537.36' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
    -H 'Sec-Fetch-Site: same-site' \
    -H 'Sec-Fetch-Mode: navigate' \
    -H 'Sec-Fetch-User: ?1' \
    -H 'Sec-Fetch-Dest: document' \
    -H 'sec-ch-ua: "Chromium";v="104", "Google Chrome";v="104", ";Not A Brand";v="99"' \
    -H 'sec-ch-ua-mobile: ?0' \
    -H 'sec-ch-ua-platform: "macOS"' \
    -H 'Referer: https://prod.adfs.federation.va.gov/' \
    -H 'Accept-Language: en-US,en;q=0.9' \
    --data-raw 'AuthMethod=CertificateAuthentication&RetrieveCertificate=1' \
    --compressed > /dev/null
  echo "Should now be authenticated.."
    # Should have MSISAuth Cookie now
  echo "Attempting to login to AWS endpoint.."
  # Curl the service retrieval endpoint
  SAML_RESPONSE=$(curl -L  -c $COOKIE_JAR -b $COOKIE_JAR \
  "https://prod.adfs.federation.va.gov/adfs/ls/idpinitiatedsignon?client-request-id=${CLIENT_REQ}" \
    -H 'Connection: keep-alive' \
    -H 'Pragma: no-cache' \
    -H 'Cache-Control: no-cache' \
    -H 'sec-ch-ua: "Chromium";v="104", "Google Chrome";v="104", ";Not A Brand";v="99"' \
    -H 'sec-ch-ua-mobile: ?0' \
    -H 'sec-ch-ua-platform: "macOS"' \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H 'Origin: https://prod.adfs.federation.va.gov' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.5112.101 Safari/537.36' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9' \
    -H 'Sec-Fetch-Site: same-origin' \
    -H 'Sec-Fetch-Mode: navigate' \
    -H 'Sec-Fetch-User: ?1' \
    -H 'Sec-Fetch-Dest: document' \
    -H 'Referer: https://prod.adfs.federation.va.gov/adfs/ls/idpinitiatedsignon?client-request-id=${CLIENT_REQ}' \
    -H 'Accept-Language: en-US,en;q=0.9' \
    --data-raw 'SignInOtherSite=SignInOtherSite&RelyingParty=3d682b83-c219-e911-80f5-00155d61e014&SignInGo=Sign+in&SingleSignOut=SingleSignOut' \
    --compressed | sed -nE 's/.*name=\"SAMLResponse\" value=\"([^"]*).*/\1/p')
    # --compressed)
  # echo "Should have a valid SAML_RESPONSE now.. writing to file (${SAML_DEST_FILE})"
  echo $SAML_RESPONSE > $SAML_DEST_FILE
  # echo """
  # Client Request: $CLIENT_REQ
  # SAML_RESPONSE: $SAML_RESPONSE
  # Cookies: $(cat $COOKIE_JAR)
  # """
  read -p "Press any key to attempt ADFS Login ..."
  echo "Resetting aws-adfs login before trying new creds .."
  echo "Trying AWS ADFS login with SAML_RESPONSE"
  aws-adfs login --adfs-host=prod.adfs.federation.va.gov --provider-id urn:amazon:webservices:govcloud --region us-gov-west-1 --no-ssl-verification --assertfile $SAML_DEST_FILE --profile ${1}
  # setting profile var
  # exporting AWS profile vars
  export AWS_PROFILE=${1}
  export AWS_DEFAULT_PROFILE=${1}
}
