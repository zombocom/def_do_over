# frozen_string_literal: true

require "did_you_do/version"

require 'parser/current'

module DidYouDo
  class Error < StandardError; end
  # Your code goes here...
  #
  def self.handle_error(e)
    file_line = e.message.split(": syntax error,").first.strip
    file, line_number = file_line.split(":")
    puts file
    puts line_number
    raise e
  end


  # class Node
  #   attr_reader :beginning, :middle, :ending

  #   def initialize(
  #     parent:,
  #     beginning:,
  #     middle:,
  #     ending:,
  #     invalid_array:,
  #     last_invalid_node:
  #   )
  #     @parent = parent
  #     @beginning = beginning
  #     @middle = middle
  #     @ending = ending
  #     @source = nil
  #   end

  #   def wrap(contents)
  #     source = String.new("")
  #     source << beginning
  #     yield source
  #     source << ending
  #     source
  #   end

  #   def empty_source
  #     parent.wrap do |s|
  #       s << beginning
  #       s << ending
  #     end
  #   end

  #   def full_source
  #     parent.wrap do |s|
  #       s << beginning
  #       s << middle
  #       s << ending
  #     end
  #   end

  #   def call
  #     # Empty phase
  #     @source = empty_source
  #     if !valid?
  #       invalid_array << self
  #       return
  #     end

  #     # Add phase
  #     @source = full_source
  #     if valid?
  #       invalid_array << last_invalid_node if last_invalid_node
  #       return
  #     else
  #       # go deeper
  #       ParseEndZones.new(middle).each do |end_zone|
  #         Node.new(
  #           parent: self,
  #           beginning: end_zone.beginning,
  #           middle: end_zone.middle,
  #           ending: end_zone.ending,
  #           invalid_array: invalid_array,
  #           last_invalid_node: self
  #         ).call
  #       end
  #     end
  #   end

  #   def valid?(source = @source)
  #     Parser::CurrentRuby.parse(source)
  #     true
  #   rescue Parser::SyntaxError
  #     false
  #   end
  # end

  # class SourceFile
  #   def initialize(file: , line_number: )
  #     @file = Pathname(file)
  #     @contents = @file.read
  #     @line_number = line_number
  #   end
  # end

  # class LevelBlock
  #   def initialize(first_line:, last_line: , contents: , line_index: )
  #     @first_line = first_line
  #     @last_line = last_line
  #     @contents = contents
  #     @line_index = line_index
  #   end
  # end

  # class EndDetect
  #   def initialize(source)
  #     @source = source
  #     @lines = source.lines
  #     @space_count_array  = []

  #     @lines.each do |line|
  #       @space_count_array << line.split(/\w/).first.length
  #     end
  #   end

  #   def level(match_level=0)
  #     first_index = nil
  #     last_index = nil
  #     @space_count_array.each_with_index do |level, i|
  #       if level == match_level
  #         if first_index.nil?
  #           first_index == i
  #         else
  #         end
  #     end
  #     LevelBlock
  #   end
  # end
end

# I would love to hook into SyntaxError directly but unfortunately
# when it's created it doesn't have any info about the file name or line number
# that created it. Internally parse.y calls rb_syntax_error_append which isn't
# exposed
require 'pathname'
module Kernel
  module_function

  alias_method :original_require, :require
  alias_method :original_require_relative, :require_relative
  alias_method(:original_load, :load)

  def load(file, wrap = false)
    original_load(file)
  rescue SyntaxError => e
    DidYouDo.handle_error(e)
  end

  def require(file)
    original_require(file)
  rescue SyntaxError => e
    DidYouDo.handle_error(e)
  end

  def require_relative(file)
    if Pathname.new(file).absolute?
      require file
    else
      require File.expand_path("../#{file}", caller_locations(1, 1)[0].absolute_path)
    end
  end

  private
end

# I honestly have no idea why this Object delegation is needed
# I keep staring at bootsnap and it doesn't have to do this
# is there a bug in their implementation they haven't caught or
# am I doing something different?
class Object
  private
  def load(path, wrap = false)
    Kernel.load(path, wrap)
  rescue SyntaxError => e
    DidYouDo.handle_error(e)
  end

  def require(path)
    Kernel.require(path)
  rescue SyntaxError => e
    DidYouDo.handle_error(e)
  end
end
