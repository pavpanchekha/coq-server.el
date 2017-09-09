#!/bin/bash

set -e -o pipefail
trap exit ERR

ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
( cd "$ABSOLUTE_PATH" && make dpipe chroot-into >/dev/null)

if [ ! -z "$SFTP_SERVER" ]; then
    : pass
elif [ -x /usr/libexec/openssh/sftp-server ]; then
    SFTP_SERVER=/usr/libexec/openssh/sftp-server
elif [ -x /usr/libexec/sftp-server ]; then
    SFTP_SERVER=/usr/libexec/sftp-server
elif [ -x /usr/lib/ssh/sftp-server ]; then
    SFTP_SERVER=/usr/lib/ssh/sftp-server
else
    echo "Please set \$SFTP_SERVER before executing \`$0\`"
    exit 127
fi
DPIPE="$ABSOLUTE_PATH"/dpipe
CHROOT_INTO="$ABSOLUTE_PATH"/chroot-into

REMOTE="$1"
shift

rmktemp() {
    ssh "$REMOTE" mktemp "$@"
}

mount_self() {
    ssh "$REMOTE" mkdir -p "$1"
    $DPIPE $SFTP_SERVER = ssh "$REMOTE" sshfs :/ "$1" -o slave -o transform_symlinks -o exec -o allow_root &
    PID=$!
    while ssh "$REMOTE" test ! -e "$1/bin"; do sleep 0.1; done
    printf "%s\n" "$PID"
}

die() {
    ERRCODE="$1"
    shift
    echo "$@"
    exit "$ERRCODE"
}

check_setup() {
    test -x $DPIPE || die "\`dpipe\` not found"
    test -x $SFTP_SERVER || die "\`sftp-server\` not found"
    test -x $CHROOT_INTO || die "\`chroot-into\` not found"
    ssh "$REMOTE" test -x /usr/bin/sshfs || die "Remote does not have \`sshfs\`"
}

get_remote_id() {
    ssh "$REMOTE" -- id | sed 's/^uid=\([0-9]\+\)([^)]\+) gid=\([0-9]\+\)([^)]\+) groups=.*$/\1:\2/'
}

check_setup

RTMP=`rmktemp -d`
scp -q "$CHROOT_INTO" "$REMOTE":"$RTMP"/chroot-into
PID=`mount_self "$RTMP"/root/`
ID=`get_remote_id`
CMD=`which $1`
shift
ssh "$REMOTE" -- sudo env PATH="$PATH" "$RTMP"/chroot-into "$RTMP"/root/ "$PWD" "$CMD" $@
RETCODE=$?
kill $PID &
exit "$RETCODE"
