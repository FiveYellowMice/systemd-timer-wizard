#!/usr/bin/env ruby
# encoding: utf-8
# forzen_string_literal: true

=begin
Copyright (c) 2016 FiveYellowMice

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

require 'io/console'
require 'readline'

def print_seperator
  puts '=' * IO.console.winsize[1]
end

def get_unix_users
  File.readlines('/etc/passwd').map{|l| l.split(':')[0] }
end

def get_systemd_units
  system_units = `systemctl list-unit-files --no-legend --no-pager`.chomp.split("\n").map{|l| l.match(/^[^ ]*/)[0] }
  user_units = `systemctl --user list-unit-files --no-legend --no-pager`.chomp.split("\n").map{|l| l.match(/^[^ ]*/)[0] }
  (system_units + user_units).uniq
end

completion_directory_files = proc do |s|
  Dir[s + '*'].select{|en| en.start_with? s }.map{|en| File.directory?(en) ? en + '/' : en }
end

completion_unix_users = proc do |s|
  get_unix_users.select{|l| l.start_with? s }
end

completion_systemd_time = proc do |s|
  %w(us ms s m h d w M y).select{|t| t.start_with? s }
end

completion_systemd_units = proc do |s|
  get_systemd_units.select{|u| u.start_with? s }
end

completion_none = proc do |s|
  []
end

module SystemdTime

  weekday = "(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)"
  weekdays = "(?:#{weekday}(?:(?:,|\\.\\.)#{weekday})*)"

  year = "(?:\\d+)"
  years = "(?:#{year}(?:(?:,|\\.\\.|/)#{year})*|\\*)"

  month = "(?:0?[1-9]|1[0-2])"
  months = "(?:#{month}(?:(?:,|\\.\\.|/)#{month})*|\\*)"

  day = "(?:0?[1-9]|[12][0-9]|3[0-1])"
  days = "(?:#{day}(?:(?:,|\\.\\.|/)#{day})*|\\*)"

  hour = "(?:[01]?[0-9]|2[0-3])"
  hours = "(?:#{hour}(?:(?:,|\\.\\.|/)#{hour})*|\\*)"

  minute = "(?:[0-5]?[0-9])"
  minutes = "(?:#{minute}(?:(?:,|\\.\\.|/)#{minute})*|\\*)"

  second = "(?:[0-5]?[0-9](?:\\.[0-9]+)?)"
  seconds = "(?:#{second}(?:(?:,|\\.\\.|/)#{second})*|\\*)"

  date = "(?:#{years}-#{months}-#{days})"
  time = "(?:#{hours}:#{minutes}(?::#{seconds})?)"

  all = %r[\A(?:#{weekdays} )?(?:#{date}(?: #{time})?|#{time})\z]i

  REGEXP = all

end

########################

puts "Welcome to Systemd Timer Wizard!"
puts "This wizard will help you to create a pair of systemd units (a service and a timer) by steps."
print "Press Enter to continue."
gets.chomp

settings = {
  save_directory:            nil,
  unit_name:                 nil,
  service_description:       nil,
  timer_description:         nil,
  exec_start:                nil,
  service_user:              nil,
  service_working_directory: nil,
  timer_type:                nil,
  on_boot_sec:               nil,
  on_unit_active_sec:        nil,
  on_calendar:               nil,
  timer_persistent:          nil,
  timer_wanted_by:           nil,
}

########################

print_seperator
puts "First, type the location where you want the created files to be saved, make sure you have write permission:"
puts "(Default is '/etc/systemd/system'.)"

Readline.completion_proc = completion_directory_files
Readline.completion_append_character = ''

loop do
  input = Readline.readline('> ', true)

  if input.empty?
    save_directory = '/etc/systemd/system'
  else
    save_directory = input.strip.sub(/\/+$/, '')
  end

  save_directory = File.expand_path(save_directory, Dir.pwd)

  if !File.exist?(save_directory)
    puts "'#{save_directory}' does not exist."
    next
  end

  if !File.directory?(save_directory)
    puts "'#{save_directory}' is not a directory."
    next
  end

  if !File.writable?(save_directory)
    puts "You don't have write permission to '#{save_directory}'."
    next
  end

  puts "Will save files to '#{save_directory}'."
  settings[:save_directory] = save_directory
  break
end

########################

print_seperator
puts "Type the name of your timer:"

Readline.completion_proc = completion_directory_files
Readline.completion_append_character = ''

loop do
  input = Readline.readline('> ', true)
  unit_name = input.strip

  if unit_name.empty?
    puts "You have to choose a name for your timer."
    next
  end

  if !(unit_name =~ /\A[a-z0-9-]+\z/)
    puts "Unit names can only contain lower case ASCII letters, numbers and hyphens."
    next
  end

  if %w(.service .timer).any?{|ex| File.exist?(File.expand_path(unit_name + ex, settings[:save_directory])) }
    puts "Either '#{unit_name}.service' or '#{unit_name}.timer' already exists in the specified path."
    next
  end

  puts "Timer will be saved as '#{unit_name}.service' and '#{unit_name}.timer'."
  settings[:unit_name] = unit_name
  break
end

########################

print_seperator
puts "Type the unit description of your service, press enter if you don't want one:"

Readline.completion_proc = completion_none
Readline.completion_append_character = ' '

loop do
  input = Readline.readline('> ', true)
  service_description = input.strip

  if service_description.empty?
    puts "Service will not have a description."
    settings[:service_description] = nil
    break
  else
    puts "Service will have a description."
    settings[:service_description] = service_description
    break
  end
end

########################

print_seperator
puts "Type the unit description of your timer, press enter if you don't want one:"

Readline.completion_proc = completion_none
Readline.completion_append_character = ' '

loop do
  input = Readline.readline('> ', true)
  timer_description = input.strip

  if timer_description.empty?
    puts "Timer will not have a description."
    settings[:timer_description] = nil
    break
  else
    puts "Timer will have a description."
    settings[:timer_description] = timer_description
    break
  end
end

########################

print_seperator
puts "Type the command to be executed when the service starts:"

Readline.completion_proc = completion_directory_files
Readline.completion_append_character = ''

loop do
  input = Readline.readline('> ', true)
  exec_start = input.strip

  if exec_start.empty?
    puts "Command can not be empty."
    next
  end

  puts "ExecStart has been set."
  settings[:exec_start] = exec_start
  break
end

########################

print_seperator
puts "Type the user this service will run as, press enter if you want the default:"

Readline.completion_proc = completion_unix_users
Readline.completion_append_character = ''

loop do
  input = Readline.readline('> ', true)
  service_user = input.strip

  if service_user.empty?
    puts "Service will be run as the default user."
    settings[:service_user] = nil
    break
  end

  if !get_unix_users.include?(service_user)
    puts "User '#{service_user}' does not exist."
    next
  end

  puts "Service will be run as #{service_user}."
  settings[:service_user] = service_user
  break
end

########################

print_seperator
puts "Type the working directory of the service, press enter if you want the default:"

Readline.completion_proc = completion_directory_files
Readline.completion_append_character = ''

loop do
  input = Readline.readline('> ', true)
  service_working_directory = input.strip.sub(/\/+$/, '')

  if service_working_directory.empty?
    puts "Working directory will not be set."
    settings[:service_working_directory] = nil
    break
  end

  if !File.exist?(service_working_directory)
    puts "'#{service_working_directory}' does not exist."
    next
  end

  if !File.directory?(service_working_directory)
    puts "'#{service_working_directory}' is not a directory."
    next
  end

  puts "Service will be run under #{service_working_directory ? "'#{service_working_directory}'" : 'the default working directory'}."
  settings[:service_working_directory] = service_working_directory
  break
end

########################

print_seperator
puts "Select timer type:"
puts "(1) monotonic"
puts "(2) realtime"

Readline.completion_proc = completion_none
Readline.completion_append_character = ''

loop do
  input = Readline.readline('Your selection (1/2): ', false)

  timer_type = [nil, :monotonic, :realtime][input.to_i]

  if !timer_type
    puts "You have to choose a timer type."
    next
  end

  puts "Timer will be #{timer_type}."
  settings[:timer_type] = timer_type
  break
end

########################

if settings[:timer_type] == :monotonic

  print_seperator
  puts "Type the time for the unit to activate after boot:"

  Readline.completion_proc = completion_systemd_time
  Readline.completion_append_character = ' '

  loop do
    input = Readline.readline('> ', true)

    on_boot_sec = input.strip

    if on_boot_sec.empty?
      puts "Time can not be empty."
      next
    end

    puts "Unit will be activated by timer #{on_boot_sec} after boot."
    settings[:on_boot_sec] = on_boot_sec
    break
  end

end

########################

if settings[:timer_type] == :monotonic

  print_seperator
  puts "Type the time gap between each activation:"

  Readline.completion_proc = completion_systemd_time
  Readline.completion_append_character = ' '

  loop do
    input = Readline.readline('> ', true)

    on_unit_active_sec = input.strip

    if on_unit_active_sec.empty?
      puts "Time can not be empty."
      next
    end

    puts "Unit will be activated by timer each #{on_unit_active_sec}."
    settings[:on_unit_active_sec] = on_unit_active_sec
    break
  end

end

########################

if settings[:timer_type] == :realtime

  print_seperator
  puts "Type the calendar expression of the timer:"
  puts "(See 'man 7 systemd.time' for help)"

  Readline.completion_proc = completion_none
  Readline.completion_append_character = ''

  loop do
    input = Readline.readline('> ', true)

    on_calendar = input.strip

    if !(on_calendar =~ SystemdTime::REGEXP)
      puts "Invalid calendar expression."
      next
    end

    puts "Unit will be activated by timer each #{on_calendar}."
    settings[:on_calendar] = on_calendar
    break
  end

end

########################

if settings[:timer_type] == :realtime

  print_seperator
  puts "Do you want the timer to be persistent?"

  Readline.completion_proc = completion_none
  Readline.completion_append_character = ''

  loop do
    input = Readline.readline('(y/n): ', false)

    timer_persistent = input.strip.downcase

    if timer_persistent == 'y'
      puts "Timer will be persistent."
      settings[:timer_persistent] = true
      break
    elsif timer_persistent == 'n'
      puts "Timer will not be persistent."
      settings[:timer_persistent] = false
      break
    else
      puts "Please type 'y' or 'n'."
    end
  end

end

########################

print_seperator
puts "Type the unit that will 'want' this timer:"
puts "(Default is 'multi-user.target')"

Readline.completion_proc = completion_systemd_units
Readline.completion_append_character = ''

loop do
  input = Readline.readline('> ', true)

  timer_wanted_by = input.strip

  if timer_wanted_by.empty?
    timer_wanted_by = 'multi-user.target'
  end

  if !get_systemd_units.include?(timer_wanted_by)
    puts "Unit '#{timer_wanted_by}' does not exist."
    next
  end

  puts "The timer will be wanted by '#{timer_wanted_by}'."
  settings[:timer_wanted_by] = timer_wanted_by
  break
end

########################

########################

print_seperator
puts "Type the unit that will 'want' this service:"
puts "(Default is 'multi-user.target')"

Readline.completion_proc = completion_systemd_units
Readline.completion_append_character = ''

loop do
  input = Readline.readline('> ', true)

  service_wanted_by = input.strip

  if service_wanted_by.empty?
    service_wanted_by = 'multi-user.target'
  end

  if !get_systemd_units.include?(service_wanted_by)
    puts "Unit '#{service_wanted_by}' does not exist."
    next
  end

  puts "The service will be wanted by '#{service_wanted_by}'."
  settings[:service_wanted_by] = service_wanted_by
  break
end

########################

print_seperator
puts "OK, all questions have been completed.\n"

service_file_name = File.expand_path(settings[:unit_name] + '.service', settings[:save_directory])
service_file_content = "[Unit]\n"
if settings[:service_description]
  service_file_content += "Description=#{settings[:service_description]}\n"
end
service_file_content += "\n[Service]\nType=oneshot\n"
if settings[:service_user]
  service_file_content += "User=#{settings[:service_user]}\n"
end
if settings[:service_working_directory]
  service_file_content += "WorkingDirectory=#{settings[:service_working_directory]}\n"
end
service_file_content += "ExecStart=#{settings[:exec_start]}\n"
service_file_content += "\n[Install]\n"
service_file_content += "WantedBy=#{settings[:service_wanted_by]}\n"

timer_file_name   = File.expand_path(settings[:unit_name] + '.timer'  , settings[:save_directory])
timer_file_content = "[Unit]\n"
if settings[:timer_description]
  timer_file_content += "Description=#{settings[:timer_description]}\n"
end
timer_file_content += "\n[Timer]\n"
if settings[:timer_type] == :monotonic
  timer_file_content += "OnBootSec=#{settings[:on_boot_sec]}\n"
  timer_file_content += "OnUnitActiveSec=#{settings[:on_unit_active_sec]}\n"
end
if settings[:timer_type] == :realtime
  timer_file_content += "OnCalendar=#{settings[:on_calendar]}\n"
  if settings[:timer_persistent]
    timer_file_content += "Persistent=true\n"
  end
end
timer_file_content += "\n[Install]\n"
timer_file_content += "WantedBy=#{settings[:timer_wanted_by]}\n"

puts "\nShowing '#{service_file_name}':"
puts service_file_content
print "Press Enter to continue."
gets.chomp

puts "\nShowing '#{timer_file_name}':"
puts timer_file_content
print "Press Enter to continue."
gets.chomp

########################

print_seperator

begin
  File.write(service_file_name, service_file_content)
  File.write(timer_file_name, timer_file_content)
rescue => e
  puts "Error saving files."
  puts "#{e.class}: #{e.message}"
  puts "Press Enter to retry, or type 's' then press Enter to save them to '/tmp'."
  if gets.chomp.strip.downcase == 's'
    temp_dir = '/tmp/' + (0...8).map{ (('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a)[rand(62)] }.join
    Dir.mkdir(temp_dir)
    File.write(File.expand_path(settings[:unit_name] + '.service', temp_dir), service_file_content)
    File.write(File.expand_path(settings[:unit_name] + '.timer', temp_dir), timer_file_content)
  else
    retry
  end
else
  puts "The files have been saved."
end
