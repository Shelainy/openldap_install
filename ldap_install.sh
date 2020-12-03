#instalacao dos pacotes iniciais
yum install openldap openldap-clients openldap-servers -y
systemctl enable slapd
systemctl start slapd

#liberacao das portas no firewall
firewall-cmd --add-service=ldap --permanent
firewall-cmd --reload

ldapadm=$1
IFS='.' read -r -a domain <<< $2

dc="dc="
comma=","

for i in "${domain[@]}"; do
    suffix+=$dc$i$comma
done

d1=${#suffix}
d2=1
l=$((d1-$d2))
suffix_final=$(echo $suffix | cut -c 1-$l)

echo "User Admin:"
pass=$(slappasswd)

echo -e "dn: olcDatabase={2}hdb,cn=config\nchangetype: modify\nreplace: olcSuffix\nolcSuffix: $suffix_final\n\ndn: olcDatabase={2}hdb,cn=config\nchangetype: modify\nreplace: olcRootDN\nolcRootDN: cn=$ldapadm,$suffix_final\n\ndn: olcDatabase={2}hdb,cn=config\nchangetype: modify\nreplace: olcRootPW\nolcRootPW: $pass" > db.ldif

echo "db.ldif Created"

ldapmodify -H ldapi:/// -f db.ldif

echo -e dn: 'olcDatabase={1}monitor,cn=config\nchangetype: modify\nreplace: olcAccess\nolcAccess: {0}to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" read by dn.base="'"cn=$ldapadm,$suffix_final"'" read by * none' > monitor.ldif

echo "monitor.ldif Created"

ldapmodify -H ldapi:/// -f monitor.ldif

cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG

chown ldap:ldap /var/lib/ldap/DB_CONFIG

ldapadd -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
ldapadd -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif
ldapadd -H ldapi:/// -f /etc/openldap/schema/nis.ldif

echo -e "dn: $suffix_final\ndc: ${domain[0]}\nobjectClass: top\nobjectClass: domain\n\ndn: cn=$ldapadm,$suffix_final\nobjectClass: organizationalRole\ncn: $ldapadm\ndescription: LDAP Manager\n\ndn: c=BR,$suffix_final\nobjectClass: country\nc:BR\n\ndn: o=filial-RS,c=BR,$suffix_final\nobjectClass: organization\no:filial-RS\n\ndn: ou=Marketing,o=filial-RS,c=BR,$suffix_final\nobjectClass:organizationalUnit\nou: Marketing\n\ndn: uid=joao,ou=Marketing,o=filial-RS,c=BR,$suffix_final\nobjectClass: top\nobjectClass: account\nobjectClass: posixAccount\ncn: joao\nuid: joao\nuidNumber: 9999\ngidNumber: 100\nhomeDirectory: /home/joao\nloginShell: /bin/bash\ngecos: Joao [LDAP]\nuserPassword: {crypt}x" > base.ldif

echo "base.ldif Created"

ldapadd -x -W -D "cn=$ldapadm,$suffix_final" -f base.ldif

echo "joao: "
ldappasswd -S -W -D "cn=$ldapadm,$suffix_final" -x "uid=joao,ou=Marketing,o=filial-RS,c=BR,$suffix_final"
