# Web Switch Project

Web switch control for these and similar products:

 * PI Manufacturing ETPW-622B
 * 5Gstore IP Switch UIS-622B
 * Proxicast IP Switch UIS-622B
 
![UIS-622B](images/web-switch.jpeg)

## Usage

```
web-switch.sh - ETPW-622B/UIS-622B web-switch control.
Usage: web-switch.sh [flags]
Option flags:
  -c --config  - Configuration file. Default: '/home/user/web-switch.conf'.
  -t --target  - Target outlet {uis 1 2 all}. Default: 'all'.
  -a --action  - Action {off on toggle reset status}. Default: 'status'.
  -h --help    - Show this help and exit.
  -v --verbose - Verbose execution. Default: ''.
  -g --debug   - Extra verbose execution. Default: ''.
  -d --dry-run - Dry run, don't send command to device.
Info:
  Project Home: https://github.com/glevand/web-switch
```

## Config File

The default location for the config file is `${HOME}/web-switch.conf`.  This can
be a symbolic link.

A typical configuration file:

```
# web-switch.sh config
# https://github.com/glevand/web-switch
#
# Environment variables will override any config file values.
#
# switch_name:     The DNS resolvable hostname or the IP address of the switch.
# switch_user:     The login user of the switch.
# switch_passwd:   The login password of the switch.
# connect_timeout: Connect timeout in seconds.

switch_name="${switch_name:-192.168.1.100}"
switch_user="${switch_user:-admin}"
switch_passwd="${switch_passwd:-012345}"
connect_timeout="${connect_timeout:-20}"
```

## Device Info

 * [PI Manufacturing ETPW-622B Programming Note](device-info/packet-request-via-http.pdf)
 * [PI Manufacturing ETPW-622B Setup Manual](device-info/etpw-622b-setup-manual.pdf)
 * [5gstore UIS-622B User Manual](device-info/IPSwitchManual_Aug_2020_rev1.pdf)
 * [Proxicast UIS-622B User Manual](device-info/proxicast-uis-622b-manual.pdf)
 * [Proxicast ezOutlet3 Manual](MSNTN02-Controlling-the-ezOutlet3.pdf)

If you find your web switch returns an auth error `/login.asp?error=1` when
sent a set command, check that your switch has the latest firmware installed.

## Typical usage

```
$ web-switch.sh --action=status
web-switch.sh: Reading status info.
web-switch.sh: Status outlet #1 = 0
web-switch.sh: Status outlet #2 = 1
web-switch.sh: Status uis       = 0
web-switch.sh: Done: Success, 0 sec.

$ web-switch.sh --action=toggle --target=1
web-switch.sh: Setting switch 1 toggle.
web-switch.sh: Status outlet #1 = 1
web-switch.sh: Status outlet #2 = 1
web-switch.sh: Status uis       = 0
web-switch.sh: Done: Success, 2 sec.

$ web-switch.sh --action=toggle --target=uis
web-switch.sh: Setting switch uis toggle.
web-switch.sh: Status outlet #1 = 1
web-switch.sh: Status outlet #2 = 1
web-switch.sh: Status uis       = 1
web-switch.sh: Done: Success, 2 sec.

$ web-switch.sh --action=off --target=2
web-switch.sh: Setting switch 2 off.
web-switch.sh: Status outlet #1 = 1
web-switch.sh: Status outlet #2 = 0
web-switch.sh: Status uis       = 1
web-switch.sh: Done: Success, 2 sec.
```

## Licence

All files in the [Web Switch Project](https://github.com/glevand/web-switch), unless
otherwise noted, are covered by an
[MIT Plus License](https://github.com/glevand/web-switch/blob/master/mit-plus-license.txt).
The text of the license describes what usage is allowed.
