#!/usr/bin/env bash
# Mount and unmounts an encrypted volume (in a toggle-fashion). 
# This is necessary because at least in Karmic, the dialog provided 
# by gnome-mount/gnome-volume-manager does not  allow the user to 
# specify a keyfile (see https://bugs.launchpad.net/gnome-mount/+bug/133520)
#
# Currently makes a number of assumptions:
#    * LUKS volume with keyfile
#    * Uses cryptmount; partition needs to be configured in cmtab.
#      We chose cryptmount due to it's general awesomeness, and in
# 	   particular since we'd need to require the calle to be su 
#      then; which means we (afaik) wouldn't be able to call this
#      script from a GNOME launcher, requiring another wrapper. 
#    * The nofsck option is set for the volume in cmtab. This is 
#      because fsck needs a terminal to run, see: 
#      http://sourceforge.net/tracker/index.php?func=detail&aid=2937347&group_id=154099&atid=790423
#

usage()
{
cat << EOF
usage: $0 CRYPT_MOUNT_NAME KEYFILE

Will mount or unmount the volume CRYPT_MOUNT_NAME configured in
cryptmount's cmtab using the contents of KEYFILE as a password.
EOF
}


# Name of the volume as defined in cmtab
cm_name=$1
# Default location of the keyfile
keyfile=$2


if [ ! $1 ] || [ ! $2 ]
then
    usage
  	exit 1
fi

mapper=/dev/mapper/${cm_name}

if mount | grep "^${mapper} on" > /dev/null
then
    echo "Umounting..."
    # Empty echo to make zentiy progress bar pulsate; artificial delay, or it won't be much to quick.
    { echo ""; cryptmount -u $cm_name; sleep 2 ;} | zenity --progress --pulsate --auto-close --title "Please wait" --text "Umounting..."
else    
    echo "Mounting..."
    if [ ! -f $keyfile ]
    then
        keyfile=`zenity --file-selection --title="$keyfile not found; select one:"`
        if [ ! $? -eq 0 ]; then 
            print "No keyfile, halting."
            exit 1;  
        fi
    fi

    # The empty "echo" makes zenity "pulsate" work, since cryptmount doesn't write to stdout.
    # Also, the challenge here is to both get the error code, as well as capture stderr. This
    # is hard because we need to get the code of a subcommand of the pipe (PIPESTATUS), but 
    # variable assignment is apparently a command of it's own and clears out PIPESTATUS.
    # For now, we use a temporary file.
    # TODO: Maybe there is a better solution. Some ideas may be here:
    # http://ask.metafilter.com/76984/Pipe-command-output-but-keep-the-error-code
    errcapture="/tmp/cryptmount.stderr.${cm_name}"
    { echo ""; cryptmount -w 5 $cm_name 2>${errcapture} 5< $keyfile ;} | \
             zenity --progress --pulsate --auto-close --title "Please wait" --text "Mouting ${cm_name}..."
    if [ ${PIPESTATUS[1]} -eq 0 ]; then
        nautilus `cat /proc/mounts | grep "^${mapper}" | awk '{print $2}'`
    else
        zenity --error --text="An error occured: `cat ${errcapture}`"
    fi
fi
