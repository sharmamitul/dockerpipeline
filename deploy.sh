#!/bin/bash


APP_ENV="${APP_ENV:-dev}"
SERVER_IP="${SERVER_IP:-${2}}"
SSH_USER="${SSH_USER:-$(whoami)}"
KEY_USER="${KEY_USER:-$(whoami)}"
DOCKER_VERSION="${DOCKER_VERSION:-1.8.3}"
BOOTSTRAP_USER="${BOOTSTRAP_USER:-docker}"
JEN_DOCKER="${JEN_DOCKER:-9d889c870dc1a080496ea5ffcc1ea264177e286c871a0d4b838b4303a7cb1f66}"
DEV_SERVER="${DEV_SERVER:-192.168.1.6}"
PROD_SERVER="${PROD_SERVER:-192.168.1.7}"

DOCKER_PULL_IMAGES=("nginx:latest")


function preseed_staging() {
cat << EOF
Dev SERVER (DIRECT VIRTUAL MACHINE) DIRECTIONS:
  1. Configure a static IP address directly on the VM
     su
     <enter password>
     nano /etc/network/interfaces
     [change the last line to look like this, remember to set the correct
      gateway for your router's IP address if it's not 192.168.1.1]
iface eth0 inet static
  address ${SERVER_IP}
  netmask 255.255.255.0
  gateway 192.168.1.1

  2. Reboot the VM and ensure the Debian CD is mounted

  3. Install sudo
     apt-get update && apt-get install -y -q sudo

  4. Add the user to the sudo group
     adduser ${SSH_USER} sudo

  5. Run the commands in: $0 --help
     Example:
       ./deploy.sh -a
EOF
}

function configure_sudo () {
  echo "Configuring passwordless sudo..."
  scp "sudo/sudoers" "${SSH_USER}@${SERVER_IP}:/tmp/sudoers"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo chmod 440 /tmp/sudoers
sudo chown root:root /tmp/sudoers
sudo mv /tmp/sudoers /etc
  '"
  echo "done!"
}

function add_ssh_key() {
  echo "Adding SSH key..."
  cat "$HOME/.ssh/id_rsa.pub" | ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
mkdir /home/${KEY_USER}/.ssh
cat >> /home/${KEY_USER}/.ssh/authorized_keys
    '"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
chmod 700 /home/${KEY_USER}/.ssh
chmod 640 /home/${KEY_USER}/.ssh/authorized_keys
sudo chown ${KEY_USER}:${KEY_USER} -R /home/${KEY_USER}/.ssh
  '"
  echo "done!"
}

function configure_secure_ssh () {
  echo "Configuring secure SSH..."
  scp "ssh/sshd_config" "${SSH_USER}@${SERVER_IP}:/tmp/sshd_config"
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo chown root:root /tmp/sshd_config
sudo mv /tmp/sshd_config /etc/ssh
sudo systemctl restart ssh
  '"
  echo "done!"
}

function install_docker () {
  echo "Configuring Docker v1.8.3..."
  ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
sudo apt-get update
sudo apt-get install -y -q libapparmor1 aufs-tools ca-certificates
wget -O "docker.deb https://apt.dockerproject.org/repo/pool/main/d/docker-engine/docker-engine_1.8.3-0~jessie_amd64.deb"
sudo dpkg -i docker.deb
rm docker.deb
sudo usermod -aG docker "${KEY_USER}"
apt-get install -y docker-compose
  '"
  echo "done!"
}

function docker_pull () {
  echo "Pulling Docker images..."
  for image in "${DOCKER_PULL_IMAGES[@]}"
  do
    ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'docker pull ${image}'"
  done
  echo "done!"
}

function chef_env(){
echo "Setting up the bootstrap environment & then prompt you for password to bootstrap the node "
wget https://packages.chef.io/files/stable/chefdk/1.2.22/ubuntu/16.04/chefdk_1.2.22-1_amd64.deb 
sudo dpkg -i chefdk_1.2.22-1_amd64.deb 
sudo mkdir -p ~/.chef/
cp chef-data/admin.pem ~/.chef/
cp chef-data/knife.rb ~/.chef/
cp chef-data/chef-validator.pem ~/.chef/
  echo "done!"
}

function bootstrap(){
echo "Bootstrapping the node"
cd ~/.chef/
knife bootstrap "{SERVER_IP}" --ssh-user "${BOOTSTRAP_USER}" --sudo --node-name "{SERVER_IP}" --run-list 'recipe[helloword-chef]'
echo "done!"
}

function warscp (){
echo "Moving .war file to git repo"
git clone git@github.com:sharmamitul/helloword-chef.git
mv /var/lib/docker/volumes/"${JEN_DOCKER}"/_data/jobs/helloword-master/workspace/target/hello-world-war-1.0.0.war  ../files/default/target
git checkout master
git commit -am "Pushing .war file to git repo"
git push origin master
echo "Done!"
}

function upload(){
echo "uploading chef cookbook to local chef server"
git clone git@github.com:sharmamitul/helloword-chef.git
knife cookbook upload helloword-chef
echo "done!"

}

function hosts(){
ssh -t "${SSH_USER}@${SERVER_IP}" bash -c "'
echo "
${DEV_SERVER} dev.assignment.com dev
${PROD_SERVER} prod.assignment.com prod
" >> /etc/hosts
  '"
echo "done!"

}
function provision_server () {
  configure_sudo
  echo "---"
  add_ssh_key
  echo "---"
  configure_secure_ssh
  echo "---"
  install_docker 
  echo "---"
  docker_pull
  echo "---"
  chef_env
  echo "---"
  bootstrap
  echo "---"
  warscp
  echo "---"
  upload
  echo "---"
  hosts
}


function help_menu () {
cat << EOF
Usage: ${0} (-h | -S | -u | -k | -s | -d [docker_ver] | -l | -c | -b | -w | -U | -H | -a )

ENVIRONMENT VARIABLES:
   APP_ENV          Environment that is being deployed to, 'staging' or 'production'
                    Defaulting to ${APP_ENV}

   SERVER_IP        IP address to work on, ie. staging or production
                    Defaulting to ${SERVER_IP}

   SSH_USER         User account to ssh and scp in as
                    Defaulting to ${SSH_USER}

   KEY_USER         User account linked to the SSH key
                    Defaulting to ${KEY_USER}

   DOCKER_VERSION   Docker version to install
                    Defaulting to ${DOCKER_VERSION}

OPTIONS:
   -h|--help                 Show this message
   -S|--preseed-staging      Preseed intructions for the staging server
   -u|--sudo                 Configure passwordless sudo
   -k|--ssh-key              Add SSH key
   -s|--ssh                  Configure secure SSH
   -d|--docker               Install Docker
   -l|--docker-pull          Pull necessary Docker images
   -c|--chef-env             Setting up chef environment
   -b|--bootstrap            Bootstrapping the node
   -w|--warscp               Moving .war file to Prod/Dev emvironment 
   -U|--upload               Uploading chef cookbook to local server
   -H|--hosts                updating hosts file
   -a|--all                  Provision everything except preseeding

EXAMPLES:
   Configure passwordless sudo:
        $ deploy -u

   Add SSH key:
        $ deploy -k

   Configure secure SSH:
        $ deploy -s

   Install Docker v${DOCKER_VERSION}:
        $ deploy -d

   Pull necessary Docker images:
        $ deploy -l

   Setting up bootstrap environment:
        $ deploy -c

   Bootstrapping the node
        $ deploy -b

   Moving .War file to Prod/Dev environment 
       $ deploy -w      

   Uploading chef cookbook to local server
       $ deploy -U      

   updating host file  
       $ deploy -H      

   Configure everything together:
        $ deploy -a


EOF
}


while [[ $# > 0 ]]
do
case "${1}" in
  -S|--preseed-staging)
  preseed_staging
  shift
  ;;
  -u|--sudo)
  configure_sudo
  shift
  ;;
  -k|--ssh-key)
  add_ssh_key
  shift
  ;;
  -s|--ssh)
  configure_secure_ssh
  shift
  ;;
  -d|--docker)
  install_docker "${DOCKER_VERSION}}"
  shift
  ;;
  -l|--docker-pull)
  docker_pull
  shift
  ;;
  -c|--chef_env)
  chef_env
  shift
  ;;
  -b|bootstrap)
  bootstrap
  shift
  ;;
  -w|--warscp)
  warscp
  shift
  ;;
  -U|--upload)
  upload
  shift
  ;;
  -H|--hosts)
  hosts
  shift
  ;;
  -a|--all)
  provision_server "${DOCKER_VERSION}}"
  shift
  ;;
  -h|--help)
  help_menu
  shift
  ;;
  *)
  echo "${1} is not a valid flag, try running: ${0} --help"
  ;;
esac
shift
done

