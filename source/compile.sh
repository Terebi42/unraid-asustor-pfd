# Clone repository and get latest commit
cd ${DATA_DIR}
mkdir -p /asustor/lib/modules/${UNAME}/kernel/drivers/platform/x86 /asustor/lib/modules/${UNAME}/kernel/drivers/hwmon /asustor/lib/modules/${UNAME}/kernel/drivers/gpio
git clone https://github.com/mafredri/asustor-platform-driver
cd asustor-platform-driver
git checkout main
PLUGIN_VERSION="$(git log -1 --format="%cs" | sed 's/-//g')"

# Compile asustor pfd Kernel Modules and install them to the temporary directory "/asustor"
make -j${CPU_COUNT}
cp asustor.ko /asustor/lib/modules/${UNAME}/kernel/drivers/platform/x86/
cp asustor_it87.ko /asustor/lib/modules/${UNAME}/kernel/drivers/hwmon/
cp asustor_gpio_it87.ko /asustor/lib/modules/${UNAME}/kernel/drivers/gpio/

#Compress modules
while read -r line
do
  xz --check=crc32 --lzma2 $line
done < <(find /asustor/lib/modules/${UNAME}/kernel -name "*.ko")

# Create Slackware package
PLUGIN_NAME="asustor_pfd"
BASE_DIR="/asustor"
TMP_DIR="/tmp/${PLUGIN_NAME}_"$(echo $RANDOM)""
VERSION="$(date +'%Y.%m.%d')"

mkdir -p $TMP_DIR/$VERSION
cd $TMP_DIR/$VERSION
cp -R $BASE_DIR/* $TMP_DIR/$VERSION/
mkdir $TMP_DIR/$VERSION/install
tee $TMP_DIR/$VERSION/install/slack-desc <<EOF
       |-----handy-ruler------------------------------------------------------|
$PLUGIN_NAME: $PLUGIN_NAME Asustor Platform Driver built from main branch
$PLUGIN_NAME:
$PLUGIN_NAME: Source: https://github.com/mafredri/asustor-platform-driver
$PLUGIN_NAME:
$PLUGIN_NAME: Custom $PLUGIN_NAME Asustor Platform driver package for Unraid Kernel v${UNAME%%-*} by ich777
$PLUGIN_NAME:
EOF
${DATA_DIR}/bzroot-extracted-$UNAME/sbin/makepkg -l n -c n $TMP_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$UNAME-1.txz
md5sum $TMP_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$UNAME-1.txz | awk '{print $1}' > $TMP_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$UNAME-1.txz.md5
