dnf update && dnf upgrade -y
dnf update && dnf upgrade
dnf install python3-pip git
dnf install libreoffice
ls
cd /home/orp
ls
cd 
lss
pwd
ss
ls
mv bin go immudb-setup.sh immudb_src openrespublica.github.io orp_engine /home/orp/
cd /home/orp
ls
mkdir -p ~/orp_engine/ssl
cd ~/orp_engine/ssl
# Create the CA serial and index files to track issued certificates
touch index.txt
echo 1000 > crlnumber
dnf install openssl
# 1. Generate Root Private Key (Keep this extremely safe!)
openssl genrsa -out sovereign_root.key 4096
# 2. Generate Root Certificate (Valid for 10 years)
openssl req -x509 -new -nodes -key sovereign_root.key -sha256 -days 3650 -out sovereign_root.crt -subj "/C=PH/ST=Negros Oriental/L=Dumaguete/O=ORP Sovereign/CN=ORP Root CA"
# 1. Generate Server Key
openssl genrsa -out orp_server.key 2048
# 2. Create Certificate Signing Request (CSR)
openssl req -new -key orp_server.key -out orp_server.csr -subj "/C=PH/ST=Negros Oriental/L=Dumaguete/O=ORP Engine/CN=localhost"
# 3. The Root CA signs the Server Certificate
openssl x509 -req -in orp_server.csr -CA sovereign_root.crt -CAkey sovereign_root.key -CAcreateserial -out orp_server.crt -days 365 -sha256
# 1. Generate Operator Key
openssl genrsa -out operator_01.key 2048
# 2. Create CSR for Operator
openssl req -new -key operator_01.key -out operator_01.csr -subj "/C=PH/ST=Negros Oriental/O=ORP Operators/CN=Marco-Admin"
# 3. Root CA signs the Operator Certificate
openssl x509 -req -in operator_01.csr -CA sovereign_root.crt -CAkey sovereign_root.key -CAcreateserial -out operator_01.crt -days 365 -sha256
# 4. Package it into a .p12 file for Windows/Chrome
# IT WILL ASK FOR AN EXPORT PASSWORD. Make one up and remember it!
openssl pkcs12 -export -out operator_01.p12 -inkey operator_01.key -in operator_01.crt -certfile sovereign_root.crt
ls /sdcard
cd /
ls
termux-setup-storage
ls
cd tmp
ls
cd ..
cd mng
cd mnt
ls
cd ..
cd /sdcard
cd storage
cd /storage
cp operator_01.p12 /storage/emulated/0/Download/
cp sovereign_root.crt /storage/emulated/0/Download/
# Copy operator_01.p12 into Termux downloads folder
cp operator_01.p12 /data/data/com.termux/files/home/downloads/
# Copy sovereign_root.crt into Termux downloads folder
cp sovereign_root.crt /data/data/com.termux/files/home/downloads/
cd /home/orp/orp_engine
ls
cd ..
l
ls
cd ~/orp_engine/ssl
ls
# Copy operator_01.p12 into Termux downloads folder
cp operator_01.p12 /data/data/com.termux/files/home/downloads/
# Copy sovereign_root.crt into Termux downloads folder
cp sovereign_root.crt /data/data/com.termux/files/home/downloads/
ls /data/data/com.termux/files/home/downloads/
cp sovereign_root.crt /data/data/com.termux/files/home/downloads/Barangay_Certs
cp operator_01.p12 /data/data/com.termux/files/home/downloads/Barangay_Certs
cp operator_01.p12 /data/data/com.termux/files/home/downloads/
cp sovereign_root.crt /data/data/com.termux/files/home/downloads/Barangay_Certs/
ls /home/downloads
ls/data/data/com.termux/files/home/
ls /data/data/com.termux/files/home/
ls /data/data/com.termux/files/home/storage
ls /data/data/com.termux/files/home/storage/downloads
ls /data/data/com.termux/files/home/storage/dcim
ls /data/data/com.termux/files/home/storage/emulated/0/downloada
ls /data/data/com.termux/files/home/storage/emulated/0/downloads
ls ~/storage/downloads/
ls ~/storage/
cd /storage
cd /
ls
cd ~/orp_engine
ls
cd ssl
pwd
exit
sudo chown root:nginx /home/orp/orp_engine/ssl/*.crt /home/orp/orp_engine/ssl/*.key
# If systemd is available
sudo systemctl restart nginx
nginx -t
nginx
pkill nginx
# run as root so ss can open netlink socket
sudo ss -ltnp | egrep ':8443|:9443' || echo "ports 8443 and 9443 are free"
# alternative if ss is unavailable
sudo lsof -nP -iTCP:8443 -sTCP:LISTEN || sudo lsof -nP -iTCP:9443 -sTCP:LISTEN
# show occurrences with line numbers
nl -ba /etc/nginx/conf.d/orp_engine.conf | sed -n '1,200p' | grep -n "ssl_client_certificate"
# open the file in an editor and remove the extra line(s)
sudo nano /etc/nginx/conf.d/orp_engine.conf
# or use sed to delete duplicates automatically (keeps the first occurrence)
sudo awk '!seen[$0]++' /etc/nginx/conf.d/orp_engine.conf > /tmp/orp_engine.conf && sudo mv /tmp/orp_engine.conf /etc/nginx/conf.d/orp_engine.conf
sudo nginx -t
# run as root
usermod -aG wheel orp
visudo
cat visudo
cat sudo
visudo
cat /etc/sudoers
# Logged in as orp
nginx -g "daemon off; pid /home/orp/.orp_vault/nginx.pid;"
exit
# run as root
cat > /etc/sudoers.d/orp <<'EOF'
orp ALL=(ALL) NOPASSWD:ALL
EOF

chmod 440 /etc/sudoers.d/orp
visudo -c
exit
su - orp 
exit
cd openrespublica.github.io
su - orp && cd  openrespublica.github.io
exit
su - orp
cd openrespublica.github.io
ls
su - irp
su - orp
lsblk
blkid
ls /storage/
USB=$(ls /storage | grep -E '^[0-9A-F]{4}-[0-9A-F]{4}$')
ln -sfn /storage/$USB ~/kingston_usb
dd if=/dev/zero of=~/kingston_usb/vault.img bs=1M count=4096
mkfs.ext4 vault.img
mkdir -p ~/mnt/vault
mount -o loop vault.img ~/mnt/vault
ls
su - orp
exit
su - orp
exit
ls
ls orp_engine
ls orp_engine/ssl
su - orp
ls
cat orp-env-bootstap
cat orp-env-bootstrap
cat orp-env-bootstrap.sh
ls
nano python_prep.sh
chmod +x python_prep.sh
ls
cp fedora-timezone.log immudb-setup-operator.sh immudb_setup.sh orp-env-bootstrap.sh orp-timezone-setup.sh python_prep.sh requirements.txt static templates /sdcard/ORP
cp -rf orp-pki-setup.sh fedora-timezone.log immudb-setup-operator.sh immudb_setup.sh orp-env-bootstrap.sh orp-timezone-setup.sh python_prep.sh requirements.txt static/js/portal.js static/css/style.css templates/portal.html /sdcard/ORP
cp orp-pki-setup.sh /sdcard/ORP/
ss
ls
mkdir docs
exit
