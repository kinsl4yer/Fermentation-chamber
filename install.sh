#!/bin/bash

# Polską wersję językową dodał kinsl4yer 11/08/2016

# Copyright 2013 BrewPi
# This file is part of BrewPi.

# BrewPi is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# BrewPi is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with BrewPi.  If not, see <http://www.gnu.org/licenses/>.

########################
### This script assumes a clean Raspbian install.
### Freeder, v1.0, Aug 2013
### Elco, Oct 2013
### Using a custom 'die' function shamelessly stolen from http://mywiki.wooledge.org/BashFAQ/101
### Using ideas even more shamelessly stolen from Elco and mdma. Thanks guys!
########################

############
### Init
###########

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "Ten skrypt musi zostać włączony z uprawnieniami administratora: sudo ./install.sh" 1>&2
   exit 1
fi

############
### Functions to catch/display errors during setup
############
warn() {
  local fmt="$1"
  command shift 2>/dev/null
  echo -e "$fmt\n" "${@}"
  echo -e "\n*** BŁĄD BŁĄD BŁĄD BŁĄD BŁĄD***\n----------------------------------\nSprawdź powyższe wiersze w celu znalezienia komunikatu błędu\nInstalacja NIE ZOSTAŁA ukończona\n"
}

die () {
  local st="$?"
  warn "$@"
  exit "$st"
}

############
### Create install log file
############
exec > >(tee -i install.log)
exec 2>&1

############
### Check for network connection
###########
echo -e "\nSprawdzanie połączenia Internetowego..."
ping -c 3 github.com &> /dev/null
if [ $? -ne 0 ]; then
    echo "------------------------------------"
    echo "Nie udało się połączyć z github.com. Czy połączenie z Internetem jest aktywne?"
    echo "Instalator zostanie wyłączony, ponieważ nie udało mu się pobrać danych z repozytorium znajdującym się na github.com"
    exit 1    
fi
echo -e "Nawiązano połączenie!\n"

############
### Check whether installer is up-to-date
############
echo -e "\nSprawdzanie aktualizacji...\n"
unset CDPATH
myPath="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
bash "$myPath"/update-tools-repo.sh
if [ $? -ne 0 ]; then
    echo "Skrypt aktualizacji nie był aktualny, ale powinien już zostać zaktualizowany. Uruchom jeszcze raz skrypt install.sh."
    exit 1
fi


############
### Install required packages
############
echo -e "\n***** Instalacja/aktualizacja niezbędnych pakietów... *****\n"
lastUpdate=$(stat -c %Y /var/lib/apt/lists)
nowTime=$(date +%s)
if [ $(($nowTime - $lastUpdate)) -gt 604800 ] ; then
    echo "Ostatnie wykonanie aktualizacji 'apt-get update' miało miejsce ponad tydzień temu. Uruchamianie 'apt-get update' przed aktualizacją zależności"
    sudo apt-get update||die
fi
sudo apt-get install -y apache2 libapache2-mod-php5 php5-cli php5-common php5-cgi php5 git-core build-essential python-dev python-pip pastebinit || die
echo -e "\n***** Instalacja/aktualizacja niezbędnych pakietów python poprzez pip(package manager)... *****\n"
sudo pip install pyserial psutil simplejson configobj gitpython --upgrade
echo -e "\n***** Ukończono przetwarzanie zależności BrewPi *****\n"


############
### Setup questions
############

free_percentage=$(df /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $5 }')
free=$(df /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $4 }')
free_readable=$(df -H /home | grep -vE '^Filesystem|tmpfs|cdrom|none' | awk '{ print $4 }')

if [ "$free" -le "512000" ]; then
    echo -e "\nZyżycie dysku wynosi $free_percentage, dostępna przestrzeń to $free_readable"
    echo "Brak wystarczającej przestrzeni do kontynuowania instalacji. Instalacja BrewPi wymaga co najmniej 512mb dostępnej przestrzeni dyskowej"
    echo "Czy partycja administratora została rozszerzona? Aby ją rozszerzyć, użyj polecenia 'sudo raspi-config', następnie rozszerz partycję administratora i zrestartuj system"
    exit 1
else
    echo -e "\nZużycie dysku wynosi $free_percentage, dostępna przestrzeń to $free_readable. To wystarczy aby zainstalować BrewPi\n"
fi


echo "Aby zaakceptować domyślną odpowiedź, wciśnij ENTER."
echo "Odpowiedź domyślna wyróżniona jest poprzez wielką literę w pytaniu Tak/Nie: [T/n]"
echo "bądź pokazana w nawiasie kwadratowym: [domyślna]"

date=$(date)
read -p "Aktualna data to $date. Czy jest właściwa? [T/n]" choice
case "$choice" in
  n | N | no | NO | No | nie | NIE | Nie )
    dpkg-reconfigure tzdata;;
  * )
esac


############
### Now for the install!
############
echo -e "\n*** Instalator zapyta Cię o ścieżkę zapisu skryptu python oraz interfejsu sieciowego"
echo "Wciśnięcie 'ENTER' zaakceptuje domyślną opcję w [nawiasie kwadratowym] (zalecane)."

echo -e "\nJakiekolwiek dane w poniższej lokalizacji zostaną w czasie instalacji USUNIĘTE!"
read -p "Proszę podać lokalizację instalacji skryptu BrewPi [/home/brewpi]: " installPath
if [ -z "$installPath" ]; then
  installPath="/home/brewpi"
else
  case "$installPath" in
    y | Y | yes | YES| Yes | T | t | tak | TAK | Tak )
        installPath="/home/brewpi";; # accept default when y/yes is answered
    * )
        ;;
  esac
fi
echo "Skrypt zostanie zainstalowany w $installPath";

if [ -d "$installPath" ]; then
  if [ "$(ls -A ${installPath})" ]; then
    read -p "Podana ścieżka NIE JEST pusta. Czy na pewno użyć tej ścieżki? [t/N] " yn
    case "$yn" in
        y | Y | yes | YES| Yes | T | t | TAK | Tak | tak ) echo "Wszystkie dane z podanej lokalizacji zostaną USUNIĘTE";;
        * ) exit;;
    esac
  fi
else
  if [ "$installPath" != "/home/brewpi" ]; then
    read -p "Podana ścieżka nie istnieje, czy utworzyć ścieżkę o danej nazwie? [T/n] " yn
    if [ -z "$yn" ]; then
      yn="y"
    fi
    case "$yn" in
        y | Y | yes | YES| Yes | T | t | TAK | Tak | tak ) echo "Tworzenie ścieżki..."; mkdir -p "$installPath";;
        * ) echo "Przerywanie..."; exit;;
    esac
  fi
fi

echo "Poszukiwanie domyślnej lokalizacji instalacji interfejsu sieciowego..."
webPath=`grep DocumentRoot /etc/apache2/sites-enabled/000-default* |xargs |cut -d " " -f2`
echo "Found $webPath"


echo -e "\nWszystkie dane z podanej lokalizacji zostaną USUNIĘTE!"
read -p "Proszę podać lokalizację instalacji interfejsu sieciowego BrewPi [$webPath]: " webPathInput

if [ "$webPathInput" ]; then
    webPath=${webPathInput}
fi

echo "Instalacja interfejsu przeglądarkowego w $webPath";

if [ -d "$webPath" ]; then
  if [ "$(ls -A ${webPath})" ]; then
    read -p "Podana ścieżka NIE JEST pusta. Czy na pewno użyć tej ścieżki? [t/N] " yn
    case "$yn" in
        y | Y | yes | YES| Yes ) echo "Wszystkie dane z podanej lokalizacji zostaną USUNIĘTE!";;
        * ) exit;;
    esac
  fi
else
  read -p "Podana ścieżka nie istnieje, czy utworzyć ścieżkę o danej nazwie? [T/n] " yn
  if [ -z "$yn" ]; then
    yn="y"
  fi
  case "$yn" in
      y | Y | yes | YES| Yes | T | t | TAK | Tak | tak ) echo "Tworzenie ścieżki..."; mkdir -p "$webPath";;
      * ) echo "Przerywanie..."; exit;;
  esac
fi

############
### Create/configure user accounts
############
echo -e "\n***** Tworzenie i konfiguracja konta użytkownika... *****"
chown -R www-data:www-data "$webPath"||die
if id -u brewpi >/dev/null 2>&1; then
  echo "Nazwa użytkownika 'brewpi' jest już zajęta, pomijanie..."
else
  useradd -G www-data,dialout brewpi||die
  echo -e "brewpi\nbrewpi\n" | passwd brewpi||die
fi
# add pi user to brewpi and www-data group
usermod -a -G www-data pi||die
usermod -a -G brewpi pi||die

echo -e "\n***** Sprawdzanie ścieżek instalacji *****"

if [ -d "$installPath" ]; then
  echo "$installPath już istnieje"
else
  mkdir -p "$installPath"
fi

dirName=$(date +%F-%k:%M:%S)
if [ "$(ls -A ${installPath})" ]; then
  echo "Lokalizacja instalacji skryptu NIE JEST pusta, następuje przywracanie lokalizacji domowej obecnego użytkownika oraz usuwanie zawartości..."
    if ! [ -a ~/brewpi-backup/ ]; then
      mkdir -p ~/brewpi-backup
    fi
    mkdir -p ~/brewpi-backup/"$dirName"
    cp -R "$installPath" ~/brewpi-backup/"$dirName"/||die
    rm -rf "$installPath"/*||die
    find "$installPath"/ -name '.*' | xargs rm -rf||die
fi

if [ -d "$webPath" ]; then
  echo "$webPath już istnieje"
else
  mkdir -p "$webPath"
fi
if [ "$(ls -A ${webPath})" ]; then
  echo "Lokalizacja instalacji interfejsu sieciowego NIE JEST pusta, następuje przywracanie lokalizacji domowej obecnego użytkownika oraz usuwanie zawartości..."
  if ! [ -a ~/brewpi-backup/ ]; then
    mkdir -p ~/brewpi-backup
  fi
  if ! [ -a ~/brewpi-backup/"$dirName"/ ]; then
    mkdir -p ~/brewpi-backup/"$dirName"
  fi
  cp -R "$webPath" ~/brewpi-backup/"$dirName"/||die
  rm -rf "$webPath"/*||die
  find "$webPath"/ -name '.*' | xargs rm -rf||die
fi

chown -R www-data:www-data "$webPath"||die
chown -R brewpi:brewpi "$installPath"||die

############
### Set sticky bit! nom nom nom
############
find "$installPath" -type d -exec chmod g+rwxs {} \;||die
find "$webPath" -type d -exec chmod g+rwxs {} \;||die


############
### Clone BrewPi repositories
############
echo -e "\n***** Pobieranie najaktualniejszego repozytorium kodu BrewPi... *****"
cd "$installPath"
sudo -u brewpi git clone https://github.com/BrewPi/brewpi-script "$installPath"||die
cd "$webPath"
sudo -u www-data git clone https://github.com/BrewPi/brewpi-www "$webPath"||die

###########
### If non-default paths are used, update config files accordingly
##########
if [[ "$installPath" != "/home/brewpi" ]]; then
    echo -e "\n***** Używanie niedomyślnej ścieżki instalacji skryptu, aktualizacjia plików konfiguracyjnych *****"
    echo "scriptPath = $installPath" >> "$installPath"/settings/config.cfg

    echo "<?php " >> "$webPath"/config_user.php
    echo "\$scriptPath = '$installPath';" >> "$webPath"/config_user.php
fi

if [[ "$webPath" != "/var/www" ]]; then
    echo -e "\n***** Używanie niedomyślnej ścieżki instalacji interfejsu sieciowego, aktualizacjia plików konfiguracyjnych *****"
    echo "wwwPath = $webPath" >> "$installPath"/settings/config.cfg
fi


############
### Fix permissions
############
echo -e "\n***** Uruchamianie fixPermissions.sh z bazy instalacyjnej. *****"
if [ -a "$installPath"/utils/fixPermissions.sh ]; then
   bash "$installPath"/utils/fixPermissions.sh
else
   echo "BŁĄD: Nie znaleziono fixPermissions.sh!"
fi

############
### Install CRON job
############
echo -e "\n***** Uruchamianie updateCron.sh z bazy instalacyjnej. *****"
if [ -a "$installPath"/utils/updateCron.sh ]; then
   bash "$installPath"/utils/updateCron.sh
else
   echo "BŁĄD: Nie znaleziono updateCron.sh!"
fi

############
### Check for insecure SSH key
############
defaultKey="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDLNC9E7YjW0Q9btd9aUoAg++/wa06LtBMc1eGPTdu29t89+4onZk1gPGzDYMagHnuBjgBFr4BsZHtng6uCRw8fIftgWrwXxB6ozhD9TM515U9piGsA6H2zlYTlNW99UXLZVUlQzw+OzALOyqeVxhi/FAJzAI9jPLGLpLITeMv8V580g1oPZskuMbnE+oIogdY2TO9e55BWYvaXcfUFQAjF+C02Oo0BFrnkmaNU8v3qBsfQmldsI60+ZaOSnZ0Hkla3b6AnclTYeSQHx5YqiLIFp0e8A1ACfy9vH0qtqq+MchCwDckWrNxzLApOrfwdF4CSMix5RKt9AF+6HOpuI8ZX root@raspberrypi"

if grep -q "$defaultKey" /etc/ssh/ssh_host_rsa_key.pub; then
  echo "Modyfikacja domyślnych kluczy SSH. Należy usunąć poprzednie You will need to remove the previous key from known hosts on any clients that have previously connected to this rpi."
  if rm -f /etc/ssh/ssh_host_* && dpkg-reconfigure openssh-server; then
     echo "Domyślne klucze SSH zostały zmodyfikowane."
  else
    echo "BŁĄD: Nie udało się zmodyfikować klucza SSH. Należy przeprowadzić tę zmianę manualnie."
  fi
fi

echo -e "Zakończono instalację BrewPi!"

echo -e "\n* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo -e "Przejrzyj powyższy log w poszukiwaniu błędów, instalacja środowiska została ukończona!"
echo -e "\nDla użytkownika ustawiono hasło 'brewpi'. Aby je zmienić, użyj komendy 'sudo passwd brewpi' i postępuj zgodnie z poleceniami"
echo -e "\nAby wejść do interfejsu sieciowego, wprowadź w przeglądarce adres http://`/sbin/ifconfig|egrep -A 1 'eth|wlan'|awk -F"[Bcast:]" '/inet addr/ {print $4}'`"
echo -e "\nPomyślnego Warzenia!"



