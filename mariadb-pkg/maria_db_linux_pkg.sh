#!/bin/bash

MARIADB_VER="10.5.8"
DIR_NAME="mariadb-$MARIADB_VER-linux-systemd-x86_64"
FNAME="$DIR_NAME.tar.gz"
MARIADB_URL=https://downloads.mariadb.org/rest-api/mariadb/$MARIADB_VER/$FNAME
target=target-linux

NCURSES_URL=http://us.archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/
NCURSES_NLIB=libncurses5_6.2-1_amd64.deb
NCURSES_TLIB=libtinfo5_6.2-1_amd64.deb

FILES=($FNAME $NCURSES_NLIB $NCURSES_TLIB)
URLS=($MARIADB_URL $NCURSES_URL$NCURSES_NLIB $NCURSES_URL$NCURSES_TLIB)

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

if ! patchelf --version >/dev/null
then
 echo "Please install patchelf"
 exit 2
fi


DNLD_RES=0
for index in ${!FILES[*]} ; do
    file=${FILES[index]}
    url=${URLS[index]}
    if [ -r $file ]
    then
     echo "File: $file already exists. Skiping download" 
    else
     wget $url
     res=$?
     if [ $res ] ; then
       echo "Download of file $file failed"
       DNLD_RES=1
     fi
    fi
done

if [ $DNLD_RES ] ; then
  echo "All files downloaded"
else
  echo "Download filed"
  exit 1
fi
 
undeb() {
 deb=$1
 echo "extracting lib: $deb"
 if [ -d debs ] ; then
   echo "debs directory exists"
 else
   mkdir debs
 fi
 cd debs
 ar x ../$deb
 tar -xvaf data.tar.*
 cd ../
}

copy_libs() {
  echo "Copying libraries"
  cp --preserve=links debs/lib/x86_64-linux-gnu/* $target/ApolloWallet/apollo-mariadb/lib
}

patch_bin() {
    ret_dir=`pwd`
    cd $target/ApolloWallet/apollo-mariadb/bin
    FILES_TO_PATCH="mariadb"
    for file in $FILES_TO_PATCH ; do
        patchelf --set-rpath '$ORIGIN/../lib' mariadb
    done    
    cd $ret_dir
}

gen_pkg_json () {
  cd $target/ApolloWallet
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
  cd ../../
}

delete_extra_from_dist(){
  cd $target/ApolloWallet/apollo-mariadb
  FILES_TO_DEL=""
  DIRS_TO_DEL="include sql-bench man mysql-test"
  for f in $FILES_TO_DEL; do
    rm -f $f
  done

  for d in $DIRS_TO_DEL; do
    rm -rf $d
  done

  cd ../../../
}


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
mv  ../../$DIR_NAME apollo-mariadb

cd apollo-mariadb
mkdir conf
cp ../../../scripts/my-apl.cnf.template conf/my-apl.cnf.template
[ ! $? -eq 0 ] && exit 1
cp ../../../scripts/create_user.sql scripts/create_user.sql
[ ! $? -eq 0 ] && exit 1

cp ../../../scripts/install-mariadb.sh ./
[ ! $? -eq 0 ] && exit 1

chmod +x install-mariadb.sh
cd ../../../

undeb ${FILES[1]}
undeb ${FILES[2]}
copy_libs
patch_bin
delete_extra_from_dist
gen_pkg_json

zip --symlink -r apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip ApolloWallet
sha256sum  apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip >  apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip.sha256
