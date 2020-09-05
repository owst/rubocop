# frozen_string_literal: true

module RuboCop
  module Cop
    module Style
      # This cop checks for unnecessary single-element Regexp character classes.
      #
      # @example
      #
      #   # bad
      #   r = /[x]/
      #
      #   # good
      #   r = /x/
      #
      #   # bad
      #   r = /[\s]/
      #
      #   # good
      #   r = /\s/
      #
      #   # good
      #   r = /[ab]/
      class RedundantRegexpCharacterClass < Base
        include RegexpLiteralHelp
        extend AutoCorrector

        REQUIRES_ESCAPE_OUTSIDE_CHAR_CLASS_CHARS = '.*+?{}()|$'.chars.freeze
        MSG_REDUNDANT_CHARACTER_CLASS = 'Redundant single-element character class, ' \
        '`%<char_class>s` can be replaced with `%<element>s`.'

        def on_regexp(node)
          each_redundant_character_class(node) do |loc|
            add_offense(
              loc, message: format(
                MSG_REDUNDANT_CHARACTER_CLASS,
                char_class: loc.source,
                element: without_character_class(loc)
              )
            ) do |corrector|
              corrector.replace(loc, without_character_class(loc))
            end
          end
        end

        private

        def each_redundant_character_class(node)
          each_single_element_character_class(node) do |char_class|
            next unless redundant_single_element_character_class?(node, char_class)

            yield node.loc.begin.adjust(begin_pos: 1 + char_class.ts, end_pos: char_class.te)
          end
        end

        def each_single_element_character_class(node)
          Regexp::Parser.parse(pattern_source(node)).each_expression do |expr|
            next if expr.type != :set || expr.expressions.size != 1
            next if expr.negative? || %i[posixclass set].include?(expr.expressions.first.type)

            yield expr
          end
        rescue Regexp::Scanner::ScannerError
          # Handle malformed patterns that are accepted by Ruby but cause the regexp_parser gem to
          # error, see https://github.com/rubocop-hq/rubocop/issues/8083 for details
        end

        def redundant_single_element_character_class?(node, char_class)
          class_elem = char_class.expressions.first.text

          non_redundant =
            whitespace_in_free_space_mode?(node, class_elem) ||
            backslash_b?(class_elem) ||
            requires_escape_outside_char_class?(class_elem)

          !non_redundant
        end

        def without_character_class(loc)
          loc.source[1..-2]
        end

        def whitespace_in_free_space_mode?(node, elem)
          return false unless freespace_mode_regexp?(node)

          /\s/.match?(elem)
        end

        def backslash_b?(elem)
          # \b's behaviour is different inside and outside of a character class, matching word
          # boundaries outside but backspace (0x08) when inside.
          elem == '\b'
        end

        def requires_escape_outside_char_class?(elem)
          REQUIRES_ESCAPE_OUTSIDE_CHAR_CLASS_CHARS.include?(elem)
        end
      end
    end
  end
end
