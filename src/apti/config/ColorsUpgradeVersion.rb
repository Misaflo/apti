# encoding: utf-8
#===============================================================================
#
# This file is part of Apti.
#
# Copyright (C) 2014-2015 by Florent Lévigne <florent.levigne at mailoo dot org>
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
    class ColorsUpgradeVersion

      #
      # @!attribute old [r]
      #   @return [Apti::Config::Color] Color of old version (upgrade).
      #
      # @!attribute new [r]
      #   @return [Apti::Config::Color] Color of new version (upgrade).
      attr_reader :old, :new

      # Initialize colors to default.
      def initialize
        require_relative 'Color'

        @old = Color.new(Color::TEXT_RED, nil, Color::EFFECT_BOLD)
        @new = Color.new(Color::TEXT_GREEN,   nil, Color::EFFECT_BOLD)
      end

      # Read upgrade-version colors from a YAML configuration (itself from a configuration file).
      #
      # @param  version  [Hash{String => String, Fixnum}]   YAML colors part.
      #
      # @return [void]
      def read_from(version)
        return if version.nil?

        @old.read_from(version['old'])
        @new.read_from(version['new'])
      end
    end
  end
end
