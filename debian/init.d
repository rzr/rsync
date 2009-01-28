#! /bin/sh

### BEGIN INIT INFO
# Provides:          rsyncd
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Should-Start:      $named
# Default-Start:     2 3 4 5
# Default-Stop:      1
# Short-Description: fast remote file copy program daemon
# Description:       rsync is a program that allows files to be copied to and
#                    from remote machines in much the same way as rcp.
#                    This provides rsyncd daemon functionality.
### END INIT INFO

set -e

# /etc/init.d/rsync: start and stop the rsync daemon

DAEMON=/usr/bin/rsync
RSYNC_ENABLE=false
RSYNC_OPTS=''
RSYNC_DEFAULTS_FILE=/etc/default/rsync
RSYNC_CONFIG_FILE=/etc/rsyncd.conf
RSYNC_NICE_PARM=''

test -x $DAEMON || exit 0

. /lib/lsb/init-functions
. /etc/default/rcS

if [ -s $RSYNC_DEFAULTS_FILE ]; then
    . $RSYNC_DEFAULTS_FILE
    case "x$RSYNC_ENABLE" in
        xtrue|xfalse)   ;;
        xinetd)         exit 0
                        ;;
        *)              log_failure_msg "Value of RSYNC_ENABLE in $RSYNC_DEFAULTS_FILE must be either 'true' or 'false';"
                        log_failure_msg "not starting rsync daemon."
                        exit 1
                        ;;
    esac
    case "x$RSYNC_NICE" in
        x[0-9])         RSYNC_NICE_PARM="--nicelevel $RSYNC_NICE";;
        x[1-9][0-9])    RSYNC_NICE_PARM="--nicelevel $RSYNC_NICE";;
        x)              ;;
        *)              log_warning_msg "Value of RSYNC_NICE in $RSYNC_DEFAULTS_FILE must be a value between 0 and 19 (inclusive);"
                        log_warning_msg "ignoring RSYNC_NICE now."
                        ;;
    esac
fi

export PATH="${PATH:+$PATH:}/usr/sbin:/sbin"

case "$1" in
  start)
	if "$RSYNC_ENABLE"; then
            log_daemon_msg "Starting rsync daemon" "rsync"
	    if [ -s /var/run/rsync.pid ] && kill -0 $(cat /var/run/rsync.pid) >/dev/null 2>&1; then
                log_progress_msg "apparently already running"
                log_end_msg 0
		exit 0
	    fi
            if [ ! -s "$RSYNC_CONFIG_FILE" ]; then
                log_failure_msg "missing or empty config file $RSYNC_CONFIG_FILE"
		log_end_msg 1
                exit 1
            fi
            if start-stop-daemon --start --quiet --background \
                --pidfile /var/run/rsync.pid --make-pidfile \
                $RSYNC_NICE_PARM --exec /usr/bin/rsync \
                -- --no-detach --daemon --config "$RSYNC_CONFIG_FILE" $RSYNC_OPTS
            then
                rc=0
                sleep 1
                if ! kill -0 $(cat /var/run/rsync.pid) >/dev/null 2>&1; then
                    log_failure_msg "rsync daemon failed to start"
                    rc=1
                fi
            else
                rc=1
            fi
            if [ $rc -eq 0 ]; then
                log_end_msg 0
            else
                log_end_msg 1
                rm -f /var/run/rsync.pid
            fi
        else
            if [ -s "$RSYNC_CONFIG_FILE" ]; then
		[ "$VERBOSE" != no ] && log_warning_msg "rsync daemon not enabled in /etc/default/rsync, not starting..."
            fi
        fi
	;;
  stop)
        log_daemon_msg "Stopping rsync daemon" "rsync"
	start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/rsync.pid
        log_end_msg $?
	rm -f /var/run/rsync.pid
	;;

  reload|force-reload)
        log_warning_msg "Reloading rsync daemon: not needed, as the daemon"
        log_warning_msg "re-reads the config file whenever a client connects."
	;;

  restart)
	set +e
        if $RSYNC_ENABLE; then
            log_daemon_msg "Restarting rsync daemon" "rsync"
	    if [ -s /var/run/rsync.pid ] && kill -0 $(cat /var/run/rsync.pid) >/dev/null 2>&1; then
		start-stop-daemon --stop --quiet --oknodo --pidfile /var/run/rsync.pid || true
		sleep 1
	    else
                log_warning_msg "rsync daemon not running, attempting to start."
	    	rm -f /var/run/rsync.pid
	    fi
            if [ ! -s "$RSYNC_CONFIG_FILE" ]; then
                log_failure_msg "missing or empty config file $RSYNC_CONFIG_FILE"
		log_end_msg 1
                exit 1
            fi
            if start-stop-daemon --start --quiet --background \
                --pidfile /var/run/rsync.pid --make-pidfile \
                $RSYNC_NICE_PARM --exec /usr/bin/rsync \
                -- --no-detach --daemon --config "$RSYNC_CONFIG_FILE" $RSYNC_OPTS
            then
                rc=0
                sleep 1
                if ! kill -0 $(cat /var/run/rsync.pid) >/dev/null 2>&1; then
                    log_failure_msg "rsync daemon failed to start"
                    rc=1
                fi
            else
                rc=1
            fi
            if [ $rc -eq 0 ]; then
                log_end_msg 0
            else
                log_end_msg 1
                rm -f /var/run/rsync.pid
            fi
        else
            [ "$VERBOSE" != no ] && log_warning_msg "rsync daemon not enabled in /etc/default/rsync, not starting..."
        fi
	;;
#  status)
#	status_of_proc -p /var/run/rsync.pid "$DAEMON" rsync && exit 0 || exit $?
#	;;

  *)
	echo "Usage: /etc/init.d/rsync {start|stop|reload|force-reload|restart}"
	exit 1
esac

exit 0
