#!/bin/bash
script_name=$0
echo "-->>> Start run $script_name .... "

MARIADB_VER="10.10.2"
DIR_NAME="mariadb-$MARIADB_VER-linux-systemd-x86_64"
FNAME="$DIR_NAME.tar.gz"
MARIADB_URL=https://downloads.mariadb.org/rest-api/mariadb/$MARIADB_VER/$FNAME
target=target-linux

NCURSES_URL=http://us.archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/
NCURSES_NLIB=libncurses5_6.3-2_amd64.deb
NCURSES_TLIB=libtinfo5_6.3-2_amd64.deb

FILES=($FNAME $NCURSES_NLIB $NCURSES_TLIB)
URLS=($MARIADB_URL $NCURSES_URL$NCURSES_NLIB $NCURSES_URL$NCURSES_TLIB)

CURRENT_ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# "

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

if ! zstd --version >/dev/null
then
 echo "Please install zstd"
 exit 2
fi


DNLD_RES=0
for index in ${!FILES[*]} ; do
    file=${FILES[index]}
    url=${URLS[index]}
    if [ -r $file ]
    then
     echo "-->> File: $file already exists. Skipping download"
    else
     echo "-->> Try download file = $file"
     wget $url
     res=$?
     if [ $res ] ; then
       echo "-->> Download of file $file failed"
       DNLD_RES=1
     fi
    fi
done

if [ $DNLD_RES ] ; then
  echo "-->> All files downloaded"
else
  echo "-->> Download failed"
  exit 1
fi
 
undeb() {
  INTERNAL_DIR="$(pwd)"
  deb=$1
  echo "-->> extracting lib: $deb into : " $INTERNAL_DIR
  if [ -d debs ] ; then
    echo "-->> debs directory exists"
  else
    echo "-->> Making debs directory..."
    mkdir debs
  fi
  cd debs
  ar xv $CURRENT_ROOT_DIR/$deb
  tar  --use-compress-program=zstd -xvaf data.tar.*
  cd ../
}

copy_libs() {
  echo "-->> Copying libraries from : " $CURRENT_ROOT_DIR/$target/ApolloWallet/apollo-mariadb " into" $CURRENT_ROOT_DIR/$target/ApolloWallet/apollo-mariadb/lib
  cp --preserve=links $CURRENT_ROOT_DIR/$target/ApolloWallet/apollo-mariadb/debs/lib/x86_64-linux-gnu/* $CURRENT_ROOT_DIR/$target/ApolloWallet/apollo-mariadb/lib
}

patch_bin() {
    ret_dir=`pwd`
    echo "-->> patch_bin with return to " $ret_dir
    cd $CURRENT_ROOT_DIR/$target/ApolloWallet/apollo-mariadb/bin
    echo "-->> patch in " `pwd`
    FILES_TO_PATCH="mariadb"
    for file in $FILES_TO_PATCH ; do
        echo "-->> patching file " $file
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
  cd $CURRENT_ROOT_DIR/$target/ApolloWallet/apollo-mariadb
  echo "-->> delete not needed extras at " `pwd`
  FILES_TO_DEL=""
  DIRS_TO_DEL="include sql-bench man mysql-test"
  for f in $FILES_TO_DEL; do
    rm -fv $f
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
echo "-->> unTar: " $FNAME
tar -xvaf $FNAME

if [ -d $target ]
then
 rm -rf $target
fi

echo "-->> Prepare folders... :" $CURRENT_ROOT_DIR " : " $target " : " $DIR_NAME
PWD=`pwd`
mkdir $target
cd $target
mkdir ApolloWallet
cd ApolloWallet
mv  ../../$DIR_NAME apollo-mariadb

echo "-->> Before copying..."

cd apollo-mariadb
mkdir conf
cp $CURRENT_ROOT_DIR/scripts/my-apl.cnf.template $CURRENT_ROOT_DIR/../$target/ApolloWallet/apollo-mariadb/conf/my-apl.cnf.template
[ ! $? -eq 0 ] && exit 1
cp $CURRENT_ROOT_DIR/scripts/create_user.sql $CURRENT_ROOT_DIR/../$target/ApolloWallet/apollo-mariadb/scripts/create_user.sql
[ ! $? -eq 0 ] && exit 1

cp $CURRENT_ROOT_DIR/scripts/install-mariadb.sh $CURRENT_ROOT_DIR/../$target/ApolloWallet/apollo-mariadb/
[ ! $? -eq 0 ] && exit 1

chmod +x $CURRENT_ROOT_DIR/$target/ApolloWallet/apollo-mariadb/install-mariadb.sh
#cd ../../../

undeb ${FILES[1]}
undeb ${FILES[2]}
copy_libs
patch_bin
delete_extra_from_dist
gen_pkg_json

zip --symlink -r apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip ApolloWallet
sha256sum  apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip >  apollo-mariadb-$MARIADB_VER-Linux-X86_64.zip.sha256

echo "FINISED !"
