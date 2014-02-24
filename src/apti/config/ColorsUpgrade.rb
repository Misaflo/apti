# encoding: utf-8
#===============================================================================
#
# This file is part of Apti.
#
# Copyright (C) 2013-2014 by Florent Lévigne <florent.levigne at mailoo dot com>
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

  module Config

    # Colors to use in apti.
    class ColorsUpgrade

      #
      # @!attribute revision [r]
      #   @return [Apti::Config::ColorsUpgradeRevision] Colors of upgrade (revision).
      #
      # @!attribute version [r]
      #   @return [Apti::Config::ColorsUpgradeVersion] Colors of upgrade (version).
      attr_reader :revision, :version

      # Initialize colors to default.
      def initialize
        require_relative 'ColorsUpgradeRevision'
        require_relative 'ColorsUpgradeVersion'

        @revision = ColorsUpgradeRevision.new
        @version  = ColorsUpgradeVersion.new
      end

      # Read upgrade colors from a YAML configuration (itself from a configuration file).
      #
      # @param  upgrade  [Hash{String => String, Fixnum}]   YAML colors part.
      def read_from(upgrade)
        if upgrade.nil?
          return
        end

        @revision.read_from(upgrade['revision'])
        @version.read_from(version['revision'])
      end

      # Write upgrade colors to a YAML configuration (itself to a configuration file).
      #
      # @return YAML colors part.
      def write_to
        return {
          'revision'    =>  @revision.write_to,
          'version'     =>  @version.write_to
        }
      end
    end

  end

end
