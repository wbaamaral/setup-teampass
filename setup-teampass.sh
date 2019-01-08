#!/bin/bash

# Versao 1.0.0
# Nome: instalarTeamPass2-debian9.sh

### 

#========================[   CORES   ]==========================================
_B=30 # Black
_R=31 # Red
_W=37 # White
_b=34 # Blue

#========================[  Efeitos  ]=========================================
_blink=1   # 
_bold=1    # Bold
_reset=0
_reverse=7 
_under=4   # Underlined 

#========================[  Variaveis ]========================================
HOMEBIN=$(cd $(dirname $0) && pwd)

HOMELOG=${HOMELOG:-"$HOMEBIN"}
ARQLOG="${HOMELOG}/SENHAS_MYSQL.TXT"

DOMINIO="dominio.lan"
SERVERADMIN="ti@email.com"
TIMEZONE="America/Porto_Velho"
MAXTIME=60
SERVERNAME="teampass.${DOMINIO}"
IP_SERVIDOR=$(ip r show|tail -n 1 |cut -d " " -f 9)
WWW="/var/www"

TEAMPAS_HOME_INSTALL="${WWW}/teampass"

VERSAOMIN=9 # Versão mínima para instalação
VERSAO=0 	# Versão atual
RELEASE=""	# Release da distribuição
DEBIAN="0" 	# Nome da distribuição

BANCO_TEAMPASS="teampass"
USER_TEAMPASS="teampass"

SOURCES_LIST=$(mktemp)

RELEASE_TEAMPASS="2.1.27.30"
URL_GIT_TEAMPASS="https://github.com/nilsteampassnet/TeamPass/archive/$RELEASE_TEAMPASS.tar.gz"

DEFAULT_PASS="BRO$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;)"
DEFAULT_TEAMPASS="XxwS$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-30};echo;)"

PASSWD_DB_ROOT=${PASSWD_DB_ROOT:-"$DEFAULT_PASS"} # senha para usuario root mysql
PASSWD_TEAMPAS_USER=${PASSWD_TEAMPAS_USER:-"$DEFAULT_TEAMPASS"} # senha para usuario teampass mysql

PACOTE_BASICO="unzip wget htop net-tools mysql-server php libapache2-mod-php php7.0-ldap php7.0-curl php7.0-mysql php7.0-mcrypt php7.0-mbstring php7.0-fpm php7.0-common php7.0-xml php7.0-gd openssl php7.0-mysql php7.0-bcmath gpm ctags vim-doc vim-scripts vim vim-runtime"

#========================[  Funcoes ]=========================================

# Verificar qual distribuição e versão
ChecarDistro(){

	if [[ -e /etc/debian_version ]]; then
		RELEASE=$(cat /etc/debian_version)
		export VERSAO=${RELEASE:0:1}
		export DEBIAN="1"
	fi
}

# Atualiza o sistema e instala pacote básico de softwares
InstalarAtualizar(){

	apt update && apt dis-upgrade -y 
	apt -y install ${PACOTE_BASICO}

}

# Setar senha do banco de dados
ConfigurarApt(){
local CODINOME=$(lsb_release -c|awk '{print $2}')

cat >/etc/apt/sources.list << __EOF__
# W.B.A.

deb http://ftp.br.debian.org/debian/ ${CODINOME} main
deb-src http://ftp.br.debian.org/debian/ ${CODINOME} main

deb http://security.debian.org/debian-security ${CODINOME}/updates main
deb-src http://security.debian.org/debian-security ${CODINOME}/updates main

# stretch-updates, previously known as 'volatile'
deb http://ftp.br.debian.org/debian/ ${CODINOME}-updates main
deb-src http://ftp.br.debian.org/debian/ ${CODINOME}-updates main

__EOF__

	debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password password $PASSWD_DB_ROOT"
	debconf-set-selections <<< "mysql-server-5.6 mysql-server/root_password_again password $PASSWD_DB_ROOT"

}

# Configura variáveis do php.ini
ConfigurarPhp(){
	
	sed -i 's/max_execution_time = 30/max_execution_time = 60/' /etc/php/7.0/fpm/php.ini
	sed -i 's/max_execution_time = 30/max_execution_time = 60/' /etc/php/7.0/apache2/php.ini

	sed -i 's@;date.timezone =@date.timezone = America/Porto_Velho@' /etc/php/7.0/fpm/php.ini
	sed -i 's@;date.timezone =@date.timezone = America/Porto_Velho@' /etc/php/7.0/apache2/php.ini
}

# configurando senha de root e ajustando segurança banco de dados
ConfigurarSegurancaDB(){

mysql --user=root << _EOF_
	UPDATE mysql.user SET Password=PASSWORD('${PASSWD_DB_ROOT}') WHERE User='root';
	DELETE FROM mysql.user WHERE User='';
	DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
	DROP DATABASE IF EXISTS test;
	DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
	FLUSH PRIVILEGES;
_EOF_

}

# Cria Banco de dados e Configura senha
CriarAmbiente(){
	
mysql -u root -p${PASSWD_DB_ROOT} <<_EOF_
	create database ${BANCO_TEAMPASS};
	grant all privileges on ${BANCO_TEAMPASS}.* to ${USER_TEAMPASS}@localhost identified by '${PASSWD_TEAMPAS_USER}';
	flush privileges;"
_EOF_
	
}

# Download dos fontes
DownloadTeamPass(){

	cd ${WWW}

	wget -c ${URL_GIT_TEAMPASS} -O teampass-${RELEASE_TEAMPASS}.tar.gz

	tar xvzf  teampass-${RELEASE_TEAMPASS}.tar.gz

	mv TeamPass-${RELEASE_TEAMPASS} ${TEAMPAS_HOME_INSTALL}

	rm -f  teampass-${RELEASE_TEAMPASS}.tar.gz

}

# Define permissões para o funcionamento do teampass
SetPermissao(){

	if [ "$DEBIAN" -eq "1" ]
	then
		USER_APACHE=$(grep APACHE_RUN_USER /etc/apache2/envvars |cut -d = -f 2)
		GROUP_APACHE=$(grep APACHE_RUN_GROUP /etc/apache2/envvars |cut -d = -f 2)
	fi

	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/includes/config
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/includes/avatars
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/includes/libraries/csrfp/libs
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/includes/libraries/csrfp/log
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/includes/libraries/csrfp/js
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/backups
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/files
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/install
	chmod -R 0777 ${TEAMPAS_HOME_INSTALL}/upload

	chown $USER_APACHE:$GROUP_APACHE -Rc ${WWW}
	#${TEAMPAS_HOME_INSTALL}

}

ConfigurarApache(){


cat >/etc/apache2/sites-available/teampass.conf <<__EOF__

<VirtualHost *:80>

	ServerName $SERVERNAME
	ServerAdmin $SERVERADMIN
	DocumentRoot ${TEAMPAS_HOME_INSTALL}

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

</VirtualHost>

__EOF__

a2dissite 000-default.conf 
a2ensite teampass.conf
systemctl reload apache2

}

CriarPastaSaltKey(){
	[ ! -d "$WWW/saltkey" ] && mkdir "$WWW/saltkey"
}
#========================[  Comandos ]=========================================
ChecarDistro

if [ $DEBIAN != 1 ]
then
	echo "Este script foi homologado apenas para distribuição Debian 9."
	echo "Caso queira muda-lo fique à vontade."
	echo "Finalizando..."

	exit 1
fi

ConfigurarApt

InstalarAtualizar

ConfigurarPhp

ConfigurarSegurancaDB

DownloadTeamPass

CriarAmbiente

CriarPastaSaltKey

SetPermissao

ConfigurarApache

reset

echo -e "\033[${_b};${_bold}m Senha do root\t: \033[${_R}m $PASSWD_DB_ROOT \033[m"
echo -e "\033[${_b};${_bold}m Caminho do saltkey\t: \033[${_R}m $WWW/saltkey \033[m"
echo -e "\033[${_b};${_bold}m Nome do banco teampass\t: \033[${_R}m ${BANCO_TEAMPASS} \033[m" 
echo -e "\033[${_b};${_bold}m Nome do usuário teampass\t: \033[${_R}m ${USER_TEAMPASS} \033[m" 
echo -e "\033[${_b};${_bold}m Senha do usuário teampass\t: \033[${_R}m ${PASSWD_TEAMPAS_USER} \033[m" 
echo -e "\033[${_b};${_bold}m Endereço do servidor\t: \033[${_R}m localhost \033[m"

echo -e "\033[41m

Utilite a interface web para concluir as configurações!!!

                http://$IP_SERVIDOR

\033[m
"
sleep 3

# Gravar log de senhas
if [[ ! -e $ARQLOG ]]
then
 touch $ARQLOG
fi

echo -e "Senha do usuario root mysql\t: $PASSWD_DB_ROOT " 		>  "${ARQLOG}"
echo -e "Caminho do saltkey\t: $WWW/saltkey " 					>> "${ARQLOG}"
echo -e "Nome do usuário teampass\t: ${USER_TEAMPASS}"			>> "${ARQLOG}"
echo -e "Nome do banco teampass\t: ${BANCO_TEAMPASS}" 			>> "${ARQLOG}"
echo -e "Senha do usuário teampass\t: ${PASSWD_TEAMPAS_USER}" 	>> "${ARQLOG}"
echo -e "Endereço do servidor\t: localhost" 					>> "${ARQLOG}"
 
