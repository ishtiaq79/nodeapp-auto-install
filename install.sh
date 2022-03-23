#!/bin/bash 

########################################################################

normal="\033[0m"
red="\033[0;31m"
redb="\033[1;31m"
green="\033[0;32m"
greenb="\033[1;32m"
yellow="\033[0;33m"
yellowb="\033[1;33m"
blue="\033[0;34m"
blueb="\033[1;34m"
purple="\033[0;35m"
purpleb="\033[1;35m"
lightblue="\033[0;36m"
lightblueb="\033[1;36m"
redblink="\033[39;31;2:39;5m"


RevBits_PAM_Server_Setup() {

echo "-----------------------------------------------------------"
echo -e "${blueb}${1} Server Dependencies: Updating and Installing ${normal}"
echo "-----------------------------------------------------------"
sudo apt-get update > /dev/null 2>&1
sudo apt-get install -y git curl wget zip unzip g++ make build-essential cmake nghttp2 libnghttp2-dev libssl-dev 
sudo apt-get install libsodium-dev -y 
sudo apt install python3 -y > /dev/null 2>&1
sudo apt install python3-pip -y > /dev/null 2>&1
sudo pip3 install --upgrade setuptools > /dev/null 2>&1
sudo pip3 install sslyze==4.1.0

echo "------------------------------------------"
echo -e "${blueb}${1} Node/NPM: Installing ${normal}"
echo "------------------------------------------"
sudo apt-get update > /dev/null 2>&1
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs

#curl -sL https://deb.nodesource.com/setup_14.x | sudo bash -
#sudo apt-get install nodejs -y 

echo "-------------------------------------------------"
echo -e "${blueb}${1} Redis: Installing/Starting ${normal}"
echo "-------------------------------------------------"
sudo apt-get -qq update > /dev/null 2>&1
sudo apt install redis-server -y 
sudo systemctl start redis-server

echo "------------------------------------------------------"
echo -e "${blueb}${1} Global NPM Packages: Installing ${normal}"
echo "------------------------------------------------------"
sudo npm install -g node-pre-gyp pm2 node-gyp nan sequelize-cli 

echo "----------------------------------------------------------------------------------------"
echo -e "${blueb}${1} krb5-user/ibpam-krb5/libpam-ccreds/libkrb5-dev: Installing ${normal}"
echo "----------------------------------------------------------------------------------------"
sudo apt install krb5-user libpam-krb5 libpam-ccreds libkrb5-dev -y

echo "-----------------------------------------"
echo -e "${blueb}${1} ffmpeg: Installing ${normal}"
echo "-----------------------------------------"
sudo apt-get -qq update > /dev/null 2>&1
sudo apt install ffmpeg -y 
echo -e "${lightblue}${1}You have done with the option#1. ${normal}" 
}


PostgreSQL_Installation() {

echo "------------------------------------------------"
echo -e "${blueb}${1} PostgreSQL: Installing ${normal}"
echo "------------------------------------------------"

echo -e " ${yellowb}${1} Press 'Y|y' if you want to install PostgreSQL on the same server. ${normal}"
echo
echo -e " ${yellowb}${1} Press 'N|n' if you already have a setup of PostgreSQL Database. ${normal}"
echo

ASK_FOR_POSTGRESS_INSTALLATION=''
echo -n "Do you want to install postgress? 'Y/N': "
read ASK_FOR_POSTGRESS_INSTALLATION

if [ $ASK_FOR_POSTGRESS_INSTALLATION = 'Y' ] || [ $ASK_FOR_POSTGRESS_INSTALLATION = 'y' ]; then
  sudo apt-get -qq -y install bash-completion wget > /dev/null 2>&1
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" |sudo tee  /etc/apt/sources.list.d/pgdg.list
  sudo apt-get -qq update > /dev/null 2>&1
  sudo apt-get -y install postgresql-12 postgresql-client-12 
  sudo systemctl start postgresql


echo -e "${blueb} Creating PostgreSQL database credentials. ${normal}"

DB_NAME=''
DB_USER=''
DB_PASS=''

echo -n "Please specify the database name. (default:revbits): "
read DB_NAME

echo -n "Please specify the superuser name. (default:revbits): "
read DB_USER

echo -n "Please specify the password. (default:revbits): "
read DB_PASS
if [ -z "$DB_NAME" ]; then
  DB_NAME=revbits
fi

if [ -z "$DB_USER" ]; then
  DB_USER=revbits
fi

if [ -z "$DB_PASS" ]; then
  DB_PASS=revbits
fi

sudo su postgres <<EOF
createdb  $DB_NAME;  
psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" 
psql -c "grant all privileges on database $DB_NAME to $DB_USER;" 
echo -e "${lightblueb}${1} Postgres User '$DB_USER' and database '$DB_NAME' created.${normal}" 
EOF

elif [ $ASK_FOR_POSTGRESS_INSTALLATION = 'N' ] || [ $ASK_FOR_POSTGRESS_INSTALLATION = 'n' ]; then
  echo -e "${yellowb} Skipping PostgreSQL database setup. ${normal}"



elif [ $ASK_FOR_POSTGRESS_INSTALLATION != 'Y|y|N|n' ] ; then
echo "Invalid option selected, please select a valid option."

sleep 2
fi
echo -e "${lightblue}${1}You have done with the option#2. ${normal}"

}

Certbot_SSL_Certificate() {

echo -e "${redb} NOTE: Application will not start until valid certificates are provided. ${normal}"


echo "-----------------------------------------------------------------"
echo -e "${blueb}${1} SSL LetsEncrypt Certificate: Generating ${normal}"
echo "-----------------------------------------------------------------"

echo -e " ${yellowb}${1} Press 'Y|y' if you want to generate SSL certificate with certbot. ${normal}"
echo
echo -e " ${yellowb}${1} Press 'N|n' if you already have SSL certificate. ${normal}"
echo
echo -e " ${yellowb}${1} Press 'Q|q' if you want to skip this action. ${normal}"
echo
ASK_FOR_SSL_CERTIFICATE=''
echo -n  "Choose your desire option to proceed: "
read ASK_FOR_SSL_CERTIFICATE

#read -p "Do you want to Install Certbot SSL Certificate? 'Y/N': " -r ASK_FOR_SSL_CERTIFICATE




if [ $ASK_FOR_SSL_CERTIFICATE = 'Y' ] || [ $ASK_FOR_SSL_CERTIFICATE = 'y' ]; then

sudo apt-get -qq update > /dev/null 2>&1
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

read -p "Enter valid domain name. : " -r DOMAIN_NAME
command="sudo certbot certonly --standalone "
command="$command -d $DOMAIN_NAME"
command="$command -n --register-unsafely-without-email --agree-tos"
eval $command


ssl_cert="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
ssl_key="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"

echo "Copy SSL certificate files to sslconf directory"
rm -rf sslconf && mkdir sslconf &&  sudo chown -R $USER:$USER  sslconf

sudo cp ${ssl_cert} sslconf
sudo cp ${ssl_key} sslconf


echo "Adding SSL certificate and private key path in .env file."
sed -i "s|SSL_CERT_PATH.*|SSL_CERT_PATH=sslconf/fullchain.pem|g" .env
sed -i "s|SSL_KEY_PATH.*|SSL_KEY_PATH=sslconf/privkey.pem|g" .env
echo ".env updated."


elif [ $ASK_FOR_SSL_CERTIFICATE = 'N' ] || [ $ASK_FOR_SSL_CERTIFICATE = 'n' ]; then

echo -e "${yellowb}${1} Please give a certificate absolute path incase you are using your own managed SSL Certificate.  ${normal}"

ASK_FOR_CERTIFICATE_CERT_PATH=''
ASK_FOR_CERTIFICATE_KEY_PATH=''

echo -n "Provide managed certificate fullchain path. e.g, /path/to/fullchain.pem : "
read ASK_FOR_CERTIFICATE_CERT_PATH

echo -n "Provide managed certificate key path. e.g, /path/to/privkey.pem : "
read ASK_FOR_CERTIFICATE_KEY_PATH
rm -rf sslconf && mkdir sslconf &&  sudo chown -R $USER:$USER  sslconf

echo "Adding SSL path in .env file"
sed -i "s|SSL_CERT_PATH.*|SSL_CERT_PATH=$ASK_FOR_CERTIFICATE_CERT_PATH|g" .env
sed -i "s|SSL_KEY_PATH.*|SSL_KEY_PATH=$ASK_FOR_CERTIFICATE_KEY_PATH|g" .env
echo ".env updated"



elif [ $ASK_FOR_SSL_CERTIFICATE != 'Y|y|N|n|' ] || [ $ASK_FOR_SSL_CERTIFICATE = 'Q' ] || [ $ASK_FOR_SSL_CERTIFICATE = 'q' ]; then
echo -e "${yellowb}{$1}Skipping this action, assuming you can set up SSL certificates of your own and update the .env file.${normal}"
sleep 2

fi
echo -e "${lightblue}${1}You have done with the option#3. ${normal}"
}

Revbits_PAM_Initialize() {

echo "--------------------------------------------------"
echo -e "${blueb}${1} PAM depenencies: Installing ${normal}"
echo "--------------------------------------------------"
npm install git+https://github.com/RevBits/node-x509 
npm i file:packages/desjs.tgz
npm i file:packages/md5js.tgz
npm i git+https://github.com/RevBits/fido2-library
npm i kerberos
npm i krb5
npm install --ignore-scripts=false --verbose sharp

echo "-----------------------------------------------"
echo -e "${blueb}${1} Revbits PAM Server: Starting ${normal}"
echo "-----------------------------------------------"

DOMAIN_NAME=''
echo -n "Please enter domain name. (for example: mydomain.com): "
read DOMAIN_NAME
node setup.js https://$DOMAIN_NAME
sudo chmod +x ./revbits-pam
sudo pm2 start ./revbits-pam
cd update-script && sudo npm i && sudo pm2 start index.js && cd ..
echo -e "${greenb}${1} Initial PAM Server setup has been completed successfully. Please visit https://$DOMAIN_NAME to setup and configure.${normal}"
echo
echo -e "${lightblue}${1}You have done with the option#4. ${normal}"
}

SelfSigned_Certificate() {
echo -e "${redblink} Important${normal}: ${red}${1}Skip this step if you already have performed with the option#3 (Certbot SSL Certificate Generation) ${normal}"


echo "----------------------------------------------------------------"
echo -e "${blueb}${1} SSL Self Signed Certificate: Generating ${normal}"
echo "----------------------------------------------------------------"
echo -e " ${yellowb}${1} Press 'Y|y' if you want to generate self signed certificate. ${normal}"
echo
echo -e " ${yellowb}${1} Press 'N|n' if you already have SSL certificate. ${normal}"
echo
echo -e " ${yellowb}${1} Press 'Q|q' if you want to skip this action. ${normal}"
echo

ASK_FOR_CERTIFICATE=''
echo -n "Choose your desire option to proceed: "
read ASK_FOR_CERTIFICATE

if [ $ASK_FOR_CERTIFICATE = 'Y' ] || [ $ASK_FOR_CERTIFICATE = 'y' ]; then

DOMAIN_NAME=''
        echo -n "Enter valid domain name. (for example: mydomain.com): "
        read DOMAIN_NAME

rm -rf sslconf && mkdir sslconf && cd sslconf
sleep 1
openssl req -new -newkey rsa:4096 -days 360 -nodes -x509 -subj "/C=US/ST=Oregon/L=Portland/O=RevBits/OU=Org/CN=$DOMAIN_NAME" -keyout certificate.key -out certificate.crt

cd ..
sleep 3
echo "Adding SSL path in .env file"
crt=sslconf/certificate.crt
key=sslconf/certificate.key
sed -i "s|SSL_CERT_PATH.*|SSL_CERT_PATH=${crt}|g" .env
sed -i "s|SSL_KEY_PATH.*|SSL_KEY_PATH=${key}|g" .env
echo ".env updated."
echo -e  "${greenb}${1} Self signed certificate successfully generated ${normal}!"
echo -e "${yellowb}${1} Warning: Self signed certificate may not work on some browsers. Try different browsers in case of any issue. ${normal}!"
sleep 3

elif [ $ASK_FOR_CERTIFICATE = 'N' ] || [ $ASK_FOR_CERTIFICATE = 'n' ]; then

echo "If you are using managed SSL certificate of your own choice then please give certificate absolute path. "
 

ASK_FOR_CERTIFICATE_CERT_PATH=''
ASK_FOR_CERTIFICATE_KEY_PATH=''

echo -n "Provide managed certificate fullchain path: e.g, /path/to/certificate.crt : "
read ASK_FOR_CERTIFICATE_CERT_PATH

echo -n "Provide managed certificate key path: e.g, /path/to/private.key : "
read ASK_FOR_CERTIFICATE_KEY_PATH
echo "Adding SSL path in .env file"
sed -i "s|SSL_CERT_PATH.*|SSL_CERT_PATH=${ASK_FOR_CERTIFICATE_CERT_PATH}|g" .env
sed -i "s|SSL_KEY_PATH.*|SSL_KEY_PATH=${ASK_FOR_CERTIFICATE_KEY_PATH}|g" .env
sleep 3
echo ".env updated."


elif [ $ASK_FOR_CERTIFICATE != 'Y|y|N|n|' ] || [ $ASK_FOR_CERTIFICATE = 'Q' ] || [ $ASK_FOR_CERTIFICATE = 'q' ]; then
echo "Skipping this step"
sleep 2

fi
echo -e "${lightblue}${1}You have done with the option#5 ${normal}"

}

while true; do


PS3="RevBits PAM Server Setup Script - Pick an option:"
options=("RevBits PAM Server Setup" "PostgreSQL Database Setup " "Certbot SSL Certificate Generation" "Starting Revbits PAM Server" "Self Signed Certificate Generation" "Quit" )
select opt in "${options[@]}";  do

    case "$REPLY" in

    #Prep
    1) RevBits_PAM_Server_Setup; break ;;

    2) PostgreSQL_Installation; break ;;

    3) Certbot_SSL_Certificate; break ;;

    4) Revbits_PAM_Initialize; break ;;

    5) SelfSigned_Certificate; break ;;

    6) echo "GoodBye"; break 2;;

    #$(( ${#options[@]}+1 )) ) echo "Goodbye!"; break;;
    *) echo "Invalid option. Try another one.";continue;;

    esac

done
done
