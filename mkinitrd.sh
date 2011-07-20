#!/bin/sh
# 
# mkinitrd.sh: Shell script to make an initial initrd image
# by Jose V Beneyto, sepen at crux dot nu

msgUsage() {
  echo "Usage: $APPNAME <options>"
  echo "Where options are:"
  echo "  --name=NAME   Name for the result image (default: initrd.gz)"
  echo "  --size=SIZE   Size expecified in bytes (default: 4096)"
  echo "  --type=TYPE   Filesystem type for the image (default: ext2)"
  echo "Example:"
  echo "  $APPNAME --name=myinitrd.gz --size=8192"
  exit 0
}

msgError() {
  echo "Error, $@" 2>&1
  exit 1
}

checkRoot() {
  [ "$(id -u)" != "0" ] && msgError "you need to be root to do this."
}

parseArgs() {
  [ $# -lt 1 ] && msgUsage
  for arg in $@; do
    case $arg in
      --name=*) IMG_NAME=${arg##*=} ;;
      --size=*) IMG_SIZE=${arg##*=} ;;
      --type=*) IMG_TYPE=${arg##*=} ;;
      *) msgUsage ;;
    esac
  done
}

main() {
  rm -rf $TMP_PATH $MNT_PATH 
  install -d $TMP_PATH $MNT_PATH
  pushd $TMP_PATH && \
  rm -f initrd
  dd if=/dev/zero of=initrd bs=1024 count=$IMG_SIZE && \
  mkfs.$IMG_TYPE -F -m 0 -b 1024 initrd $IMG_SIZE && \
  mount -v -o loop -t $IMG_TYPE initrd $MNT_PATH && \
  rm -rf $MNT_PATH/lost+found && \
  install -d -m 0755 $MNT_PATH/{mnt,media,etc,dev,sys,proc,lib,usr,var/{log,lock,run},tmp} && \
  mknod $MNT_PATH/dev/console c 5 1 && chmod 666 $MNT_PATH/dev/console && \
  mknod $MNT_PATH/dev/null c 1 3 && chmod 666 $MNT_PATH/dev/null && \
  mknod $MNT_PATH/dev/tty c 5 0 && chmod 666 $MNT_PATH/dev/tty && \
  mkdir $MNT_PATH/dev/rd && mknod $MNT_PATH/dev/rd/0 b 1 0
  mknod $MNT_PATH/dev/ram0 b 1 0 && chmod 600 $MNT_PATH/dev/ram0
  for i in 0 1 2 3 4 5 6 7; do
    mknod $MNT_PATH/dev/tty$i c 4 $i && chmod 666 $MNT_PATH/dev/tty$i
  done && \
  umount -v $MNT_PATH && \
  gzip -v initrd && \
  popd && \
  mv $TMP_PATH/initrd.gz $IMG_NAME
}

APPNAME="$(basename $0)"

TMP_PATH="$(cd $(dirname $APPNAME); pwd)/.tmp"
MNT_PATH="$(cd $(dirname $APPNAME); pwd)/.mnt"

IMG_SIZE=4096       # default image size = 4MB
IMG_TYPE=ext2       # default filesystem type = ext2

export PATH=$PATH:/sbin:/usr/sbin

checkRoot
parseArgs $@ && \
main || msgError "$APPNAME failed"

umount -v $MNT_PATH
rm -rf $TMP_PATH $MNT_PATH

# End of file
