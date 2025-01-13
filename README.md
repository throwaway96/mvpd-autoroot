# mvpd-autoroot

> [!IMPORTANT]
> This hasn't been well tested yet.

This is a tool to root and automatically install
[Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel) on
LG TVs with webOS 1 through 3.4.2. It uses a vulnerability in `mvpd-service`.

As far as I know, the vulnerable service is not present in webOS 3.5 and newer.
For those versions, try
[dejavuln-autoroot](https://github.com/throwaway96/dejavuln-autoroot) or
[faultmanager-autoroot](https://github.com/throwaway96/faultmanager-autoroot)
instead.

## Instructions

1. Set up
   [Developer Mode](https://webostv.developer.lge.com/develop/getting-started/developer-mode-app).
2. Connect to the TV with an SSH client. (If you need help, see the
   [crashd guide](https://gist.github.com/throwaway96/e811b0f7cc2a705a5a476a8dfa45e09f#alternative-clients).
   [Dev Manager](https://github.com/webosbrew/dev-manager-desktop) should
   also work.)
3. Download `autoroot.sh` to any writable directory (e.g., `/tmp`).
4. Run `autoroot.sh` (e.g., `sh /tmp/autoroot.sh`).
5. Wait for the `Payload complete` message; the script should exit soon after.
6. **Before rebooting**, uninstall the LG Developer Mode app.

**Do not** install the LG Developer Mode app while the TV is rooted!

## Example

```sh
curl -L -o /tmp/autoroot.sh -- 'https://raw.githubusercontent.com/throwaway96/mvpd-autoroot/refs/heads/main/autoroot.sh' &&
sh /tmp/autoroot.sh
```

## Settings

The `autoroot.sh` script accepts certain command line options:

* `--debug` or `-d` - Enables additional logging.
* `--telnet` or `-t` - Makes a root shell available via telnet on port 23.
  Note that this won't work on webOS 9 (24), which does not have `telnetd`!
* `--leave-script` - Don't rename `start-devmode.sh` with invalid signature.
  You almost certainly won't need this, but it's documented here for the sake
  of completeness.

If there is a file named `hbchannel.ipk` in the same directory as
`autoroot.sh`, it will be installed. Otherwise, the latest Homebrew Channel
IPK will be downloaded and installed.

## Troubleshooting

Check the log files. They are named `autoroot.log` and `autoroot-payload.log`.

If the toast and/or log says "Rooting complete" but you don't see Homebrew
Channel, reboot the TV. Make sure Quick Start+ is disabled.

If you get an error installing the IPK (e.g., `errorCode` -5), make sure your
TV's date is set to something reasonably accurate.

## Support

You can find more information at [webosbrew.org](https://www.webosbrew.org/).

If you need help rooting your TV, try the
[OpenLGTV Discord](https://discord.gg/hXMHAgJC5R). Before you ask a question,
check the FAQ (#faq) to see if it is answered there! Attach your `autoroot.log`
and `autoroot-payload.log` (if present) when asking for help.

## License

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>.

See `COPYING` for details.
