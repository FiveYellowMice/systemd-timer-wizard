# Systemd Timer Wizard

We all love systemd, it's a great tool that does a lot of stuff on itself. But when it comes to write timers instead of cron jobs, things get slightly cumbersome to deal with: You have to create 2 massive files, a service and a timer, then `systemctl daemon-reload`, and start your new timer, possibly enable it to make it starts at boot time, then check `systemctl list-timers` to see if it is working properly. Compare to crontabs which only involves adding a line to a file, it's just not so convenient.

So, here comes Systemd Timer Wizard. It's a nice script that guides you to create a service and a timer file, interactively, through few steps. No more typing `[Unit]` and stuff repeatedly.

## Usage

Just download the <systemd-timer-wizard.rb> file in this repository, and save it somewhere in your `$PATH`. Then you can start the wizard by just typing `systemd-timer-wizard.rb` in the command line.

Note Systemd Timer Wizard required Ruby 1.9.3 or above, which is very easy to insall from your distro's package manager unless you are using some acient distros like CentOS 6 or Debian 6.
