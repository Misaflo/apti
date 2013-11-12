#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'src/apti/Apti'

# Enable warnings.
$VERBOSE = true

apti = Apti::Apti.new
packages = ARGV[1..(ARGV.length - 1)].join(' ')

case ARGV[0]

when '--help'
  apti.help
when '-h'
  apti.help

when '--version'
  apti.version

when 'safe-upgrade'
  apti.upgrade(packages)

when 'upgrade'
  puts 'Warning: upgrade is deprecated, use safe-upgrade.'
  apti.upgrade(packages)

when 'full-upgrade'
  apti.upgrade(packages, true)

when 'search'
  apti.search(packages)

when 'update'
  apti.execute_command('aptitude update')

when 'remove'
  apti.remove(packages)

when 'purge'
  apti.remove(packages, true)

when 'install'
  apti.install(packages)

when 'stats'
  apti.stats

# other aptitude command
else
  if ARGV[0].eql?(nil)
    help

  else
    apti.execute_command "aptitude #{ARGV[0]} #{packages}"
  end

end
