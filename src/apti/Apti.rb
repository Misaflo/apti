# encoding: utf-8
#===============================================================================
#
# This file is part of Apti.
#
# Copyright (C) 2012-2015 by Florent Lévigne <florent.levigne at mailoo dot org>
# Copyright (C) 2013-2014 by Julien Rosset <jul.rosset at gmail dot com>
#
#
# Apti is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Apti is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#===============================================================================

module Apti

  require 'i18n'
  require_relative 'config/Config'
  require_relative 'version'

  class Apti
    NEED_SUPERUSER_RIGHTS = [
      'install', 'remove', 'purge', 'hold', 'unhold', 'keep', 'reinstall',
      'markauto', 'unmarkauto', 'build-depends', 'build-dep', 'forbid-version',
      'update', 'safe-upgrade', 'full-upgrade', 'keep-all', 'forget-new',
      'clean', 'autoclean'
    ]

    #
    # @!attribute config [r]
    #   @return [Apti::Config::Config] Config.
    #
    # @!attribute VERSION [r]
    #   @return [String] Apti's version.
    attr_reader :config, :VERSION

    # Reads the configuration file, and define locale.
    #
    # @return [void]
    def initialize
      @config = Config::Config.new

      locales_path = "#{File.dirname("#{__FILE__}")}/../../locales"
      lang = `echo $LANG`.split('_').first

      I18n.enforce_available_locales = true if defined? I18n.enforce_available_locales

      I18n.load_path = Dir[File.join(locales_path, '*.yml')]
      I18n.default_locale = :en

      if defined? I18n.locale_available?
        I18n.locale = lang if I18n.locale_available?(lang)
      else
        I18n.locale = lang
      end
    end

    # Display help.
    #
    # @return [void]
    def help
      puts "usage: #{File.basename $0} commande"
      puts 'Commandes:'
      puts '  update'
      puts '  safe-upgrade'
      puts '  search package'
      puts '  install package'
      puts '  remove package'
      puts '  others aptitude commande...'
      puts '  stats'
    end

    # Display version.
    #
    # @return [void]
    def version
      puts "apti #{VERSION}"
      puts I18n.t(:using)
      puts "  aptitude #{`aptitude --version | head -n 1 | cut -d ' ' -f 2`}"
      puts "  ruby #{`ruby --version | cut -d ' ' -f 2`}"
    end

    # Install packages.
    #
    # @param package [String] List of packages to install.
    #
    # @return [void]
    def install(package)
      usage if package.eql?(nil)

      # Check if some packages does not exist.
      packages_not_found = get_packages_not_found(package.split)

      if !packages_not_found.empty?
        puts I18n.t(:'error.package.not_found', packages: packages_not_found.join(' '))
        exit 1
      end

      # Check if all packages are not already installed.
      packages_already_installed = all_installed?(package.split)

      if packages_already_installed
        puts I18n.t(:'error.package.installed')
        exit 1
      end

      aptitude_string = `aptitude install -VZs --allow-untrusted --assume-yes #{package}`
      command = "aptitude install #{package}"

      # If problem with dependencies: display aptitude's message.
      if aptitude_string.include?('1)')
        puts aptitude_string
        exit 1
      end

      packages = aptitude_string.split(/ {2}/)
      operation = I18n.t(:'operation.installing')
      question = I18n.t(:'operation.question.installation')

      if display_packages(packages, operation, 'install', question, aptitude_string.split(/\n/)[-2])
        execute_command(command, true)
      end
    end

    # Remove / Purge packages.
    #
    # @param package  [String]  List of packages to remove / purge.
    # @param purge    [Boolean] True if purging packages, else removing.
    #
    # @return [void]
    def remove(package, purge = false)
      require_relative 'Package'

      # Check if some packages does not exist.
      packages_not_found = get_packages_not_found(package.split)

      if !packages_not_found.empty?
        puts I18n.t(:'error.package.not_found', packages: packages_not_found.join(' '))
        exit 1
      end

      # Check if all packages are not uninstalled (only for remove).
      if !purge
        packages_not_installed = all_not_installed?(package.split)

        if packages_not_installed
          puts I18n.t(:'error.package.not_installed')
          exit 1
        end
      end

      if purge
        aptitude_string = `aptitude purge -VZs --assume-yes #{package}`
        command = "aptitude purge #{package}"
        operation = I18n.t(:'operation.purging')
        question = I18n.t(:'operation.question.purge')

      else
        aptitude_string = `aptitude remove -VZs --assume-yes #{package}`
        command = "aptitude remove #{package}"
        operation = I18n.t(:'operation.removing')
        question = I18n.t(:'operation.question.remove')
      end

      # If problem with dependencies, wrong name given,
      # or trying to remove a virtual package : display aptitude's message.
      if aptitude_string.include?('1)') || aptitude_string.include?('«')
        puts aptitude_string
        exit 0

      # If the package is not installed.
      elsif !aptitude_string.include?(':')
        puts I18n.t(:package_not_installed)
        exit 0
      end

      # Remove the "p" parameter on packages to purge.
      aptitude_string.sub!(/\{p\}/, '')

      # Split packages.
      packages = aptitude_string.split(/ {2}/)

      if display_packages(packages, operation, 'remove', question, aptitude_string.split(/\n/)[-2])
        execute_command(command, true)
      end
    end

    # Do upgrade (safe-upgrade or full-upgrade).
    #
    # @param packages     [String]  List of packages to upgrade.
    # @param full_upgrade [Boolean] True if full-upgrade, else safe-upgrade.
    #
    # @return [void]
    def upgrade(packages, full_upgrade = false)
      if full_upgrade
        aptitude_string = `aptitude full-upgrade -VZs --allow-untrusted --assume-yes #{packages}`
        command = "aptitude full-upgrade #{packages}"

      else
        aptitude_string = `aptitude safe-upgrade -VZs --allow-untrusted --assume-yes #{packages}`
        command = "aptitude safe-upgrade #{packages}"
      end

      # If problem with dependencies, use aptitude.
      if aptitude_string.include?('1)')
        execute_command(command)
        exit 0

      # If there is no package to upgrade.
      elsif !aptitude_string.include?(':')
        puts I18n.t(:system_is_up_to_date)
        exit 0
      end

      # Split packages.
      packages = aptitude_string.split(/ {2}/)
      operation = I18n.t(:'operation.upgrading')
      question = I18n.t(:'operation.question.upgrade')

      if display_packages(packages, operation, 'upgrade', question, aptitude_string.split(/\n/)[-2])
        execute_command(command, true)
      end
    end

    # Search packages.
    #
    # @param package_name [String] Package(s) to search.
    #
    # @return [void]
    def search(package_name)
      require_relative 'Package'

      # For details of the output format, see: http://aptitude.alioth.debian.org/doc/en/ch02s05s01.html#secDisplayFormat
      aptitude_string = `aptitude search --disable-columns -F "%c %M|%p|%d" #{package_name}`
      terminal_width  = `tput cols`.to_i

      # Information size (i, p, A, ...) : 6 seems to be good.
      package_parameter_length_alignment = 6

      get_search_packages(aptitude_string).each do |package|
        print package.parameter

        print ''.rjust(package_parameter_length_alignment - package.parameter.length)

        # Display package name: if the package is installed, we display it in color.
        if package.parameter.include?('i')
          print "#{@config.colors.install.to_shell_color}#{package.name}#{get_color_for()}"
        else
          print package.name
        end

        print ''.rjust(@config.spaces.search - package.name.length)

        size_of_line = package_parameter_length_alignment + @config.spaces.search + package.description.length

        # If description is too long, we shorten it.
        if size_of_line > terminal_width
          package.description = package.description[0..(terminal_width - package_parameter_length_alignment - @config.spaces.search - 1)]
        end

        puts "#{@config.colors.description.to_shell_color}#{package.description.chomp}#{get_color_for}"
      end
    end

    # Print stats about packages.
    #
    # @return [void]
    def stats
      packages_installed            = `dpkg --get-selections | grep -v deinstall | wc -l`
      packages_installed_explicitly = `aptitude search '~i !~M' | wc -l`
      cache_size                    = `du -sh /var/cache/apt/archives/ | cut -f 1`

      puts "#{`lsb_release -ds`}\n"

      puts I18n.t(:'stat.total_installed', number: packages_installed)
      puts I18n.t(:'stat.explicitly_installed', number: packages_installed_explicitly)
      puts I18n.t(:'stat.space_used_in_cache', size: cache_size)
    end

    # Execute the command with superuser rights if needed.
    #
    # @param command    [String]  Command to execute.
    # @param no_confirm [Boolean] If true execute the command without asking confirmation (--assume-yes).
    #
    # @return [void]
    def execute_command(command, no_confirm = false)
      if !NEED_SUPERUSER_RIGHTS.include?(command.split[1])
        system(command)

      elsif `groups`.split.include?('sudo')
        if no_confirm && @config.no_confirm
          system("sudo #{command} --assume-yes")
        else
          system("sudo #{command}")
        end

      else
        if no_confirm && @config.no_confirm
          system("su -c '#{command} --assume-yes'")
        else
          system("su -c '#{command}'")
        end
      end
    end

    private

    # Return an array of packages that does not exist.
    #
    # @param packages [Array<String>] Packages to check.
    #
    # @return [Array<String>] Packages not found.
    def get_packages_not_found(packages)
      require_relative 'Package'

      not_found = []

      packages.each do |package_name|
        # If we use option (ex: -t sid), we don't check if packages exist.
        return [] if package_name =~ /^-.*$/

        pkg = Package.new
        pkg.name = package_name

        not_found.push(package_name) if !pkg.exist?
      end

      not_found
    end

    # Check if all packages are already installed.
    #
    # @param packages [Array<String>] Packages to check.
    #
    # @return [Boolean]
    def all_installed?(packages)
      require_relative 'Package'

      all_installed = true

      packages.each do |package_name|
        pkg = Package.new
        pkg.name = package_name
        all_installed = false if !pkg.is_installed?
      end

      all_installed
    end

    # Check if all packages are not installed.
    #
    # @param packages [Array<String>] Packages to check.
    #
    # @return [Boolean]
    def all_not_installed?(packages)
      require_relative 'Package'

      all_not_installed = true

      packages.each do |package_name|
        pkg = Package.new
        pkg.name = package_name
        all_not_installed = false if pkg.is_installed?
      end

      all_not_installed
    end

    # Separate packages in analysis parts (only for install, remove and upgrade).
    #
    # Return a Hash like +Hash{max, packages}+ with:
    #
    # * max: Apti::Package,             Fake package with max lengths of all attributs.
    # * packages: Array<Apti::Package>, Array of packages.
    # @param packages_line [Array<String>] List of packages, as outputted by aptitude.
    #
    # @return [Hash]
    def analysis_packages(packages_line)
      require_relative 'Package'

      max = Package.new
      max.name                = I18n.t(:'header.package')
      max.version_static      = ''
      max.version_old         = I18n.t(:'header.version')
      max.version_new         = ''
      max.size_before_decimal = ''
      max.size_after_decimal  = ''
      max.size_unit           = ''

      # Longest text for packages with no-revision (see below for explanations).
      max_old_static          = ''

      thousands_separator = I18n.t(:'number.separator.thousands')
      decimal_separator   = I18n.t(:'number.separator.decimal')

      packages = []

      packages_line.delete_if { |package| package == '' || package == "\n" }

      packages_line.each do |package_line|
        # ex: brasero-common{a} [3.8.0-2 -> 3.8.0-5] <+11,2 MB>
        #   name          : brasero-common
        #   parameter     : a
        #   old version   : 3.8.0
        #   old revision  : 2
        #   new version   : 3.8.0
        #   new revision  : 5
        #   size before   : +11
        #   size after    : 2
        #   size_unit     : MB
        if package_line =~ /
            ^([[:alnum:]+.:-]*)                 # Package name.
            (?:\{([[:alpha:]])\})?              # Package parameter (a,u,...) if any.
            \p{Space}
            \[
              ([[:alnum:][:space:]+.:~]*)       # Old version (without revision).
              (?:-([[:alnum:][:space:]+.:~-]+))?  # Old revision (if any).
              (?:
                \p{Space}->\p{Space}              # Separator : ->
                ([[:alnum:]+.:~]*)                # New version (without revision).
                (?:-([[:alnum:]+.:~-]+))?         # New revision (if any).
              )?
            \]
            (?:\p{Space}<
              ([+-]?                                                          # Size symbol.
             [[:digit:]]{1,3}(?:[#{thousands_separator}]?[[:digit:]]{3})*)    # Size before decimal : integer part.
              ([#{decimal_separator}][[:digit:]]+)?                           # Size after  decimal : decimal part.
              \p{Space}
              ([[:alpha:]]+)                                                  # Size unit.
            >)?$
          /x
          package = Package.new

          package.name                = Regexp.last_match(1)
          package.parameter           = Regexp.last_match(2)

          if Regexp.last_match[3] == Regexp.last_match(5)     # If old version (without revision) and new version (without revision) are identical => only "revision" upgrade.
            package.version_static = Regexp.last_match(3);      # Version (without revision).
            package.version_old    = Regexp.last_match(4);      # Old revision.
            package.version_new    = Regexp.last_match(6);      # New revision.

            max.version_static = package.version_static if package.version_static.length > max.version_static.length

            # Sometimes, there are package without revision information.
            # In this case we assign '' to version_old to prevent crash.
            package.version_old ||= ''

            max.version_old = package.version_old if package.version_old.length > max.version_old.length

          else                                                # Else => "version" upgrade or not an upgrade.
            package.version_static = nil                        # No "root" version : used to know if "revision" upgrade or not.
            package.version_old    = Regexp.last_match(3)       # "Old" version => always present.

            # Add revision if exists.
            package.version_old = "#{package.version_old}-#{Regexp.last_match(4)}" if !Regexp.last_match(4).nil?

            if !Regexp.last_match(5).nil?                       # And only if new version exist.
              package.version_new = Regexp.last_match(5)          # Remember it.
              package.version_new = "#{package.version_new}-#{Regexp.last_match(6)}" if !Regexp.last_match(6).nil?
            end

            max_old_static = package.version_old if package.version_old.length > max_old_static.length
          end

          package.size_before_decimal = Regexp.last_match(7)
          package.size_after_decimal  = Regexp.last_match(8)
          package.size_unit           = Regexp.last_match(9)

          max.name = package.name                               if package.name.length > max.name.length
          max.version_new = package.version_new                 if !package.version_new.nil? && package.version_new.length > max.version_new.length
          max.size_before_decimal = package.size_before_decimal if !package.size_before_decimal.nil? && package.size_before_decimal.length > max.size_before_decimal.length
          max.size_after_decimal = package.size_after_decimal   if !package.size_after_decimal.nil? && package.size_after_decimal.length > max.size_after_decimal.length
          max.size_unit = package.size_unit                     if !package.size_unit.nil? && package.size_unit.length > max.size_unit.length

          packages.push(package)
        end
      end

      # Check if longest text of no-revision upgrades (including install or remove) are greater than bloc of longest version and longest old revision of revision upgrades.
      # Must be done AFTER treating all packages to ensure to use REALLY longest parts!
      if max_old_static.length > (max.version_old.length + max.version_static.length)
        # If so, this is first part ("root" version part) must be increased.
        max.version_static = max_old_static.slice(0, max_old_static.length - max.version_old.length)
      else
        # If not, we must add spaces between `static` version and old revision or it will be collapse.
        max.version_static = max.version_static.rjust(max.version_static.length + @config.spaces.columns)
      end

      out = {}
      out['max']= max
      out['packages'] = packages

      out
    end

    # Return an Array of the package(s) searched.
    #
    # @param aptitude_string [String] Output of aptitude search's command.
    #
    # @return [Array<Apti::Package>] Array of packages.
    def get_search_packages(aptitude_string)
      require_relative 'Package'

      packages = []

      aptitude_string.each_line do |package_line|
        package = Package.new

        package_array = package_line.split('|')

        package.parameter = package_array[0]
        package.name = package_array[1]
        package.description = "- #{package_array[2]}"

        packages.push(package)
      end

      packages
    end

    # Display all packages of an operation (install, remove or upgrade).
    #
    # @param packages       [Array<String>] List of packages as outputted by aptitude.
    # @param operation      [String]        Operation requested : "Installing", "Upgrading" or "Removing".
    # @param color          [String]        Color (Linux bash color notation) to use for old / current package version.
    # @param question       [String]        Question to ask for continuing operation after displaying packages list.
    # @param download_size  [String]        Aptitude's text about download sizes.
    #
    # @return [Boolean] Answer for executing aptitude's command.
    def display_packages(packages, operation, color, question, download_size)
      analysis  = analysis_packages(packages)
      max       = analysis['max']
      packages  = analysis['packages']

      explicit    = []
      dep_install = []
      dep_remove  = []

      packages.each do |package|
        case package.parameter
        when 'a'
          dep_install.push(package)

        when 'u'
          dep_remove.push(package)

        else
          explicit.push(package)
        end
      end

      # If we do an upgrade, we separate new revisions and new versions.
      if operation.eql?(I18n.t(:'operation.upgrading'))
        upgrade = true

        upgrade_revisions = []
        upgrade_versions = []

        explicit.each do |package|
          if package.version_static.nil?
            upgrade_versions.push(package)
          else
            upgrade_revisions.push(package)
          end

        end
      end

      if explicit.empty?
        puts I18n.t(:'operation.nothing_to_do')
        exit 1
      end


      print_header(max.name.length, max.version_all.length)

      # If we have packages to upgrade, we display them at the end (after news to install, and those to remove).
      if !upgrade
        puts "#{@config.colors.text.to_shell_color}#{operation}#{get_color_for()}"
        explicit.each { |package| display_package_line(package, max, color) }
        puts ''
      end

      if !dep_install.empty?
        puts "#{@config.colors.text.to_shell_color}#{I18n.t(:installing_for_dependencies)}#{get_color_for}"
        dep_install.each { |package| display_package_line(package, max, 'install') }
        puts ''
      end

      if !dep_remove.empty?
        puts "#{@config.colors.text.to_shell_color}#{I18n.t(:removing_unused_dependencies)}#{get_color_for}"
        dep_remove.each { |package| display_package_line(package, max, 'remove') }
        puts ''
      end

      if upgrade
        if !upgrade_revisions.empty?
          puts "#{@config.colors.text.to_shell_color}#{I18n.t(:'operation.upgrading')} #{I18n.t(:'operation.new_revisions')}#{get_color_for}"
          upgrade_revisions.each { |package| display_package_line(package, max, color) }
          puts ''
        end

        if !upgrade_versions.empty?
          puts "#{@config.colors.text.to_shell_color}#{I18n.t(:'operation.upgrading')} #{I18n.t(:'operation.new_versions')}#{get_color_for}"
          upgrade_versions.each { |package| display_package_line(package, max, color) }
          puts ''
        end
      end

      # Size to download and install.
      puts download_size

      answer = ''
      while !answer.downcase.eql?('y') && !answer.downcase.eql?('n')
        print "\n#{@config.colors.text.to_shell_color}#{question} (Y/n)#{get_color_for} "
        answer = STDIN.gets.chomp
        answer = 'y' if answer.empty?
      end

      answer.downcase.eql?('y')
    end

    # Displaying the line of ONE package (for install, remove and upgrade).
    #
    # @param package   [Apti::Package] The package to display.
    # @param max       [Apti::Package] Fake package with max lengths of all attributs.
    # @param operation [String]        Name of sub-variable of Apti::config.colors according to current operation (install, upgrade or remove).
    #
    # @return [void]
    def display_package_line(package, max, operation)
      # Name.
      print "  #{package.name}"
      # Spaces.
      print ''.rjust((max.name.length - package.name.length) + @config.spaces.columns)

      # Package version (with revision if new version, without if new revision).
      if package.version_static.nil?
        print "#{get_color_for(operation, 'version.old')}#{package.version_old}"
      else
        print "#{get_color_for(operation, 'revision.static')}#{package.version_static}"
      end
      print "#{get_color_for}"

      if !package.version_new.nil?
        print "#{''.rjust((max.version_old.length + max.version_static.length) - package.version_old.length - (package.version_static.nil? ? 0 : package.version_static.length))}"
        print "#{get_color_for(operation, 'revision.old')}#{package.version_old}#{get_color_for()}" if !package.version_static.nil?
        print " -> #{get_color_for(operation, (package.version_static.nil? ? 'version' : 'revision') + '.new')}#{package.version_new}#{get_color_for}"
        rjust_size = max.version_new.length - package.version_new.length
      else
        rjust_size = max.version_all.length - package.version_old.length
      end

      if @config.display_size && !package.size_before_decimal.nil?
        line_size_after_length = (package.size_after_decimal.nil? ? 0 : package.size_after_decimal.length)

        # Spaces.
        print ''.rjust(rjust_size + @config.spaces.columns + max.size_before_decimal.length - package.size_before_decimal.length)
        # Start color.
        print @config.colors.size.to_shell_color
        # Size.
        print "#{package.size_before_decimal}#{package.size_after_decimal}"
        # Spaces and unit.
        print package.size_unit.rjust((max.size_after_decimal.length - line_size_after_length) + (max.size_unit.length) + @config.spaces.unit)
        # End color.
        print get_color_for
      end

      print "\n"
    end

    # Get color of an "operation" (install, upgrade or remove).
    # In case of "upgrade" operation, a sub-operation can be provide to access the desired color (examples in Apti::display_package_line code).
    #
    # If no "operation" is get, return the special Config::Color::STYLE_END color.
    #
    # @param operation [String] The "operation".
    # @param sub_op    [String] The sub-operation, separate levels with dot.
    #
    # @return [String] The shell notation of the color.
    def get_color_for(operation = nil, sub_op = nil)
      if operation.nil?
        color = Config::Color.new(Config::Color::STYLE_END)
      else
        # Get the config field according to current operation.
        color = @config.colors.send(operation)

        if operation == 'upgrade' && !sub_op.nil?
          # Must be do level by level because Object::send doesn't support dots (not like expected).
          sub_op.split('.').each { |sub_var| color = color.send(sub_var) }
        end
      end

      # Directly change color to shell notation.
      color.to_shell_color
    end

    # Print header for install, remove and upgrade.
    #
    # @param largest_name     [Fixnum]  Largest size of package name.
    # @param largest_version  [Fixnum]  Largest size of complete version (old / current AND new).
    #
    # @return [void]
    def print_header(largest_name, largest_version)
      terminal_width  = `tput cols`.to_i

      # Top line.
      terminal_width.times { print '=' }
      print "\n"

      # Column's names.
      header_package = I18n.t(:'header.package')
      header_version = I18n.t(:'header.version')
      header_size    = I18n.t(:'header.size')

      print "  #{header_package}"
      print "#{''.rjust(largest_name - header_package.length + @config.spaces.columns)}"
      print "#{header_version}"
      if @config.display_size
        print "#{''.rjust(largest_version - header_version.length + @config.spaces.columns + 1)}"
        print "#{header_size}"
      end
      print "\n"

      # Bottom line.
      terminal_width.times { print '=' }
      print "\n"
    end
  end
end
