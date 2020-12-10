#!/bin/bash

MARIADB_VER="10.5.8"
DIR_NAME="mariadb-$MARIADB_VER-linux-systemd-x86_64"
FNAME="$DIR_NAME.tar.gz"
MARIADB_URL=https://downloads.mariadb.org/rest-api/mariadb/$MARIADB_VER/$FNAME
target=target-linux

if ! wget -V >/dev/null
then
 echo "Please install wget"
 exit 2
fi

if ! zip -v >/dev/null
then
 echo "Please install zip"
 exit 2
fi

DNLD_RES=0
if [ -r $FNAME ]
then
 echo "$FNAME already exists. Skiping download" 
else
 wget $MARIADB_URL
 DNLD_RES=$?
fi

if [ ! $DNLD_RES ]
then
 echo "Download error!!!"
 exit 1
fi

if [ -d $DIR_NAME ]
then
 rm -rf $DIR_NAME
fi

tar -xvaf $FNAME

if [ -d $target ]
then
 rm -rf $target
fi
PWD=`pwd`
mkdir $target
cd $target
mkdir ApolloWallet
cd ApolloWallet
mkdir packaging
cd packaging
PF="pkg-apollo-mariadb.json"
echo "{" > $PF
echo "  \"name\": \"apollo-mariadb\"," >>$PF
echo "  \"description\": \"Apollo mariadb server\"," >>$PF
echo "  \"version\": \"$MARIADB_VER\"," >>$PF
echo "  \"dependencies\": [" >>$PF
echo "  ]" >>$PF
echo "}" >> $PF
cd ../
mv  ../../$DIR_NAME apollo-mariadb
cd apollo-mariadb

FILES_TO_DEL=""
DIRS_TO_DEL="include sql-bench man mysql-test"
for f in $FILES_TO_DEL; do
  rm -f $f
done

for d in $DIRS_TO_DEL; do
  rm -rf $d
done

cd ../../

zip --symlink -r apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip ApolloWallet
sha256sum  apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip >  apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip.sha256
