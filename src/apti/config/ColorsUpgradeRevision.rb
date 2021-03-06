# encoding: utf-8
#===============================================================================
#
# This file is part of Apti.
#
# Copyright (C) 2014-2015 by Florent Lévigne <florent.levigne at mailoo dot org>
# Copyright (C) 2014 by Julien Rosset <jul.rosset at gmail dot com>
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

    require_relative 'ColorsUpgradeVersion'

    # Colors to use in apti.
    class ColorsUpgradeRevision < ColorsUpgradeVersion

      #
      # @!attribute static [r]
      #   @return [Apti::Config::Color] Color of static part of version (upgrade).
      attr_reader :static

      # Initialize colors to default.
      def initialize
        require_relative 'Color'

        super
        @static = Color.new(Color::TEXT_WHITE, nil, Color::EFFECT_BOLD)
      end

      # Read upgrade-version colors from a YAML configuration (itself from a configuration file).
      #
      # @param  revision  [Hash{String => String, Fixnum}]   YAML colors part.
      def read_from(revision)
        return if revision.nil?

        super(revision)
        @static.read_from(revision['static'])
      end
    end
  end
end
