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

# leds-gpio / gpio-keys-polled (+ LED triggers): the asustor module registers "leds-gpio" and
# "gpio-keys-polled" platform devices, but Unraid's kernel config has LEDS_GPIO and
# KEYBOARD_GPIO_POLLED unset, so without these the LEDs and the USB Copy button get no driver.
# Built as in-tree single targets from the same, already built kernel tree (vmlinux and
# Module.symvers present), so vermagic, the in-tree flag and symbol resolution are the kernel's own.
# The tree's .config is restored afterwards, so nothing else in this build changes.
KDIR="$(readlink -f /lib/modules/${UNAME}/build)"
cp "${KDIR}/.config" "${KDIR}/.config.asustor-orig"
"${KDIR}/scripts/config" --file "${KDIR}/.config" -m LEDS_GPIO -m KEYBOARD_GPIO_POLLED \
  -m LEDS_TRIGGER_TIMER -m LEDS_TRIGGER_HEARTBEAT -m LEDS_TRIGGER_TRANSIENT -m LEDS_TRIGGER_PATTERN -m LEDS_TRIGGER_DEFAULT_ON
make -C "${KDIR}" olddefconfig
EXTRA_KO="drivers/leds/leds-gpio.ko drivers/input/keyboard/gpio_keys_polled.ko drivers/leds/trigger/ledtrig-timer.ko drivers/leds/trigger/ledtrig-heartbeat.ko drivers/leds/trigger/ledtrig-transient.ko drivers/leds/trigger/ledtrig-pattern.ko drivers/leds/trigger/ledtrig-default-on.ko"
make -C "${KDIR}" -j${CPU_COUNT} ${EXTRA_KO}
for ko in ${EXTRA_KO}; do
  mkdir -p "/asustor/lib/modules/${UNAME}/kernel/$(dirname ${ko})"
  cp "${KDIR}/${ko}" "/asustor/lib/modules/${UNAME}/kernel/${ko}"
done
mv "${KDIR}/.config.asustor-orig" "${KDIR}/.config"

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
# A Slackware package extracts over /; keep the modules tree root-owned and not world-writable
# (the 2025.12 packages carry drwxrwxrwx dirs and -rw-rw-rw- modules).
find $TMP_DIR/$VERSION -type d -exec chmod 755 {} +
find $TMP_DIR/$VERSION -type f -exec chmod 644 {} +
tee $TMP_DIR/$VERSION/install/slack-desc <<EOF
       |-----handy-ruler------------------------------------------------------|
$PLUGIN_NAME: $PLUGIN_NAME Asustor Platform Driver built from main branch
$PLUGIN_NAME:
$PLUGIN_NAME: Source: https://github.com/mafredri/asustor-platform-driver
$PLUGIN_NAME: plus leds-gpio, gpio-keys-polled and LED triggers from the kernel tree
$PLUGIN_NAME:
$PLUGIN_NAME: Custom $PLUGIN_NAME Asustor Platform driver package for Unraid Kernel v${UNAME%%-*} by ich777
$PLUGIN_NAME:
EOF
${DATA_DIR}/bzroot-extracted-$UNAME/sbin/makepkg -l n -c n $TMP_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$UNAME-1.txz
md5sum $TMP_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$UNAME-1.txz | awk '{print $1}' > $TMP_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$UNAME-1.txz.md5
