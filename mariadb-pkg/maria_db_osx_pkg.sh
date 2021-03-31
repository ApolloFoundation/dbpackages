#!/bin/sh
#

if ! brew -v >/dev/null
then
 echo "Please install brew from https://brew.sh/"
 exit 2
fi

vstring=$(brew ls --versions mariadb)
if [ -z "${vstring}" ] ; then
  echo "installing MariaDB by brew"
  brew install mariadb
  vstring=$(brew ls --versions mariadb)
fi 

MARIADB_VER=$(echo $vstring | cut -d' ' -f 2)

echo "Maria DB version is $MARIADB_VER"
PWD=`pwd`
TGT="target/ApolloWallet"
rm -rf target
mkdir -p $TGT
cp -r /usr/local/Cellar/mariadb/$MARIADB_VER $TGT
cd $TGT
mv $MARIADB_VER apollo-mariadb

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
cd ..

cd apollo-mariadb
mkdir conf
cp ../../..//mariadb-pkg/scripts/my-apl.cnf.template conf/my-apl.cnf.template
[ ! $? -eq 0 ] && exit 1
cp ../../../mariadb-pkg/scripts/create_user.sql scripts/create_user.sql
[ ! $? -eq 0 ] && exit 1

cp ../../../mariadb-pkg/scripts/install-mariadb.sh ./
[ ! $? -eq 0 ] && exit 1

chmod +x install-mariadb.sh

FILES_TO_DEL="INSTALL_RECEIPT.json homebrew.mxcl.mariadb.plist"
DIRS_TO_DEL="include .brew .bottle"

for f in $FILES_TO_DEL; do
  echo "deleting $f"    
  rm -f $f
done

for d in $DIRS_TO_DEL; do
  rm -rf $d
done

function patch_rpath {
 local fn=$1
 echo "$fn ======== rpath"

}

function chk_deps_and_patch {
 local fn=$1
# libraries will be copied in "lib" sub-directory of "bin" directory
 local dest=$2/lib
 local dl_name
 if [ ! -d $dest ] ; then
    mkdir -p $dest
 fi
 # we count on brew-installed dependecies only from /usr/local
 DEP_LIBS=`otool -L ./$fn | grep  "/usr/local" | awk '{if (NR!=1) print $1}'`
 for dl in $DEP_LIBS ; do
    echo "$fn ======== dep: $dl"
    dl_name="${dl##*/}"
    echo "======= Name: $dl_name"
    if [ -r $dest/$dl_name ] ; then
	echo "===== file $dl_name aready copied"
    else
       echo "===== Copying file $dl_name to $dest"
       cp $dl $dest
    fi
    echo "Changing $dl to @loader_path/lib/$dl_name in file $bf"
    chmod u+w $bf 
    install_name_tool -change "$dl" "@loader_path/lib/$dl_name" $bf
    chmod u-w $bf
 done
}


echo "Patching binaries, replacing @rpath"
cd bin
BIN_FILES=$( ls );
DIST_DST=`pwd`

for bf in $BIN_FILES ; do
    ft=$( file $bf | grep "Mach-O")
    if [ -z "${ft}" ] ; then
      echo "$bf is is not binary executable. Skiping."
    else
      echo "--- Checking dependencies of $bf ---"
      chk_deps_and_patch $bf $DIST_DST
    fi
done

echo "Creating distributive zip"
cd ../../..

zip --symlink -r apollo-mariadb-$MARIADB_VER-Darwin-X86_64.zip ApolloWallet
shasum -a 256 apollo-mariadb-$MARIADB_VER-Darwin-X86_64.zip > apollo-mariadb-$MARIADB_VER-Darwin-X86_64.zip.sha256
