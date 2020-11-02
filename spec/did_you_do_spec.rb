RSpec.describe DidYouDo do
  def ruby(script)
    `ruby -I#{lib_dir} -rdid_you_do #{script} 2>&1`
  end

  describe "foo" do
    around(:each) do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = Pathname(dir)
        @script = @tmpdir.join("script.rb")
        example.run
      end
    end

    it "blerg" do
      @script.write <<~EOM
        describe "things" do
          it "blerg" do
          end

          it "flerg"
          end

          it "zlerg" do
          end
        end
      EOM

      require_rb = @tmpdir.join("require.rb")
      require_rb.write <<~EOM
        require_relative "./script.rb"
      EOM

      # out = ruby(require_rb)
      # puts out
    end
  end

  module SpaceCount
    def self.indent(string)
      string.split(/\w/).first&.length || 0
    end
  end

  # Chunks ruby source based on indentation and `end` locations
  #
  #  source = <<~EOM
  #     describe "first" do
  #     end
  #
  #     describe "next" do
  #       Foo.new.call
  #     end
  #   EOM
  #
  #   zones = ParseEndZones.new(source)
  #   zone = zones.first
  #   puts zone[:beginning] => "describe "first" do"
  #   puts zone[:middle]    => ""
  #   puts zone[:ending]    => "end"
  #
  class ParseEndZones
    include Enumerable

    def initialize(source)
      @lines = source.lines
      @array = []
      @indent_count_array = []

      # Keys are the number of spaces of indent,
      # values are the index of the line where the `end` is
      @space_count_end_index_hash = Hash.new {|h, k| h[k] = [] }

      count_indents

      # An array that represents different "levels" of indents
      # the index of the array is the level, the return is the number of
      # spaces for that level
      @space_count_for_level_array = @space_count_end_index_hash.keys.sort

      level(0)
    end

    private def count_indents
      @lines.each.with_index do |line, i|
        count = line.split(/\w/).first.length
        @indent_count_array << count

        next unless line.strip == "end"
        @space_count_end_index_hash[count] << i
      end
    end

    def each
      return @array.each unless block_given?

      @array.each do |x|
        yield x
      end
    end

    private def level(level)
      spaces = @space_count_for_level_array[level]
      @space_count_end_index_hash[spaces].each do |end_index|
        middle = []
        beginning = nil

        end_index.pred.downto(0).each do |i|
          line = @lines[i]

          if @indent_count_array[i] == spaces
            beginning = line.chomp
            break
          else
            middle << line
          end
        end

        @array << {ending: @lines[end_index].chomp, beginning: beginning, middle: middle.reverse.join($/)}
      end
    end

    def length
      @array.length
    end

    def to_array
      @array
    end
  end

  describe "end zone parsing" do
    it "chunks ends" do
      source = <<~EOM
        describe "first" do
        end

        describe "next" do
          Foo.new.call
        end
      EOM

      zones = ParseEndZones.new(source)
      expect(zones.length).to eq(2)

      zones.to_array.first.tap do |z|
        expect(z[:beginning]).to include(%Q{describe "first" do})
        expect(z[:middle]).to include(%Q{})
        expect(z[:ending]).to include(%Q{end})
      end

      zones.to_array.last.tap do |z|
        expect(z[:beginning]).to include(%Q{describe "next" do})
        expect(z[:middle]).to include(%Q{Foo.new.call})
        expect(z[:ending]).to include(%Q{end})
      end
    end
  end

  class CodeNode
    def self.valid?(source)
      # Parser writes to stderr even if you catch the error
      stderr = $stderr
      $stderr = StringIO.new

      Parser::CurrentRuby.parse(source)
      true
    rescue Parser::SyntaxError
      false
    ensure
      $stderr = stderr
    end

    def self.invalid?(source)
      !valid?(source)
    end

    attr_reader :beginning, :middle, :ending, :parent, :invalid_nodes

    class NullParent
      def wrap
        source = []
        yield source
        source.join($/)
      end
    end

    def initialize(beginning: , middle: , ending: , parent: NullParent.new, invalid_nodes: [])
      @beginning = beginning
      @middle = middle
      @ending = ending
      @parent = parent
      @source = nil
      @invalid_nodes = invalid_nodes
    end

    SYNTAX_SUGGESTION = "# <--- Check your syntax here, maybe".freeze
    OMITTED = "# ...".freeze

    private def invalid_empty
      # Make output prettier
      if !@middle.strip.empty? && (line = @middle.lines.first)
        @middle = " " * SpaceCount.indent(line) + OMITTED
      else
        @middle = ""
      end

      @beginning = @beginning.chomp + " #{SYNTAX_SUGGESTION}"
      invalid_nodes << self
    end

    def call
      if CodeNode.invalid?(empty_source)
        invalid_empty and return
      end

      if CodeNode.invalid?(full_source)
        ParseEndZones.new(middle).each do |zone|
          CodeNode.new(
            beginning: zone[:beginning],
            middle: zone[:middle],
            ending: zone[:ending],
            parent: self,
            invalid_nodes: invalid_nodes
          ).call
        end
      end
    end

    def wrap
      source = []
      source << beginning
      yield source
      source << ending
      source.join($/)
    end

    def empty_source
      parent.wrap do |s|
        s << beginning
        s << ending
      end
    end

    def full_source
      parent.wrap do |s|
        s << beginning
        s << middle unless middle.empty?
        s << ending
      end
    end
  end

  class SuggestSyntax
    def initialize(source, io: STDOUT)
      @source = source
      @io = io
    end

    def call
      invalid_nodes = []
      ParseEndZones.new(@source).each do |zone|
        CodeNode.new(
          beginning: zone[:beginning],
          middle: zone[:middle],
          ending: zone[:ending],
          invalid_nodes: invalid_nodes
        ).call
      end

      out = invalid_nodes.map do |node|
         node.full_source
      end.join($/+$/)

      @io.puts out
    end
  end

  describe "suggest syntax" do
    #it "suggests syntax" do
    #  io = StringIO.new
    #  source = <<~EOM
    #   Array(value).each |x|
    #   end

    #   # I'm fine

    #   begon
    #     Foo.call
    #   rescue
    #      # stuff
    #      # here
    #      # but its fine
    #   end
    #  EOM
    #  SuggestSyntax.new(source, io: io).call

    #  puts io.string

    #  expect(io.string).to eq(<<~EOM)
    #    Array(value).each |x| #{CodeNode::SYNTAX_SUGGESTION}
    #    end

    #    begon #{CodeNode::SYNTAX_SUGGESTION}
    #    rescue
    #      #{CodeNode::OMITTED}
    #    end
    #  EOM
    #end

  end

  describe "integration" do
    it "finds nested nodes" do
      source = <<~EOM
        describe "lol"
        end

        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
        end
      EOM

      invalid_nodes = []
      ParseEndZones.new(source).each do |zone|
        CodeNode.new(
          beginning: zone[:beginning],
          middle: zone[:middle],
          ending: zone[:ending],
          invalid_nodes: invalid_nodes
        ).call
      end

      expect(invalid_nodes.length).to eq(2)
      expect(invalid_nodes.first.full_source).to include(%Q{describe "lol"})
      expect(invalid_nodes.first.full_source).to eq(<<~EOM.strip)
       describe "lol" #{CodeNode::SYNTAX_SUGGESTION}
       end
      EOM
      expect(invalid_nodes.last.full_source).to include(%Q{  Foo.call})

      expect(invalid_nodes.last.full_source).to eq(<<~EOM.strip)
       describe "hi" do
         Foo.call #{CodeNode::SYNTAX_SUGGESTION}
         end
       end
      EOM
    end
  end

  describe "code node" do
    it "finds invalid sub nodes" do
      invalid_nodes = []
      node = CodeNode.new(
        beginning: "def foo",
        middle:    "  bar\n  end",
        ending:    "end",
        invalid_nodes: invalid_nodes,
      )
      node.call

      expect(invalid_nodes.length).to eq(1)
      expect(invalid_nodes.first).to_not eq(node)
      expect(invalid_nodes.first.full_source).to eq(<<~EOM.strip)
        def foo
          bar #{CodeNode::SYNTAX_SUGGESTION}
          end
        end
      EOM
    end

    it "likes valid code" do
      invalid_nodes = []
      node = CodeNode.new(
        beginning: "def foo",
        middle:    "  puts 'lol'",
        ending:    "end",
        invalid_nodes: invalid_nodes,
      )
      node.call

      expect(invalid_nodes.length).to eq(0)
    end

    it "finds invalid empty code" do
      invalid_nodes = []
      node = CodeNode.new(
        beginning: "defzfoo",
        middle:    "  puts 'lol'",
        ending:    "end",
        invalid_nodes: invalid_nodes,
      )
      node.call

      expect(invalid_nodes.length).to eq(1)
      expect(invalid_nodes.first).to eq(node)
      expect(invalid_nodes.first.full_source).to eq(<<~EOM.strip)
        defzfoo #{CodeNode::SYNTAX_SUGGESTION}
          #{CodeNode::OMITTED}
        end
      EOM
    end

    it "wraps code" do
      node = CodeNode.new(
        beginning: "def foo",
        middle:    "  puts 'lol'",
        ending:    "end"
      )

      expect(node.empty_source).to eq(<<~EOM.strip)
        def foo
        end
      EOM

      expect(node.full_source).to eq(<<~EOM.strip)
        def foo
          puts 'lol'
        end
      EOM
    end

    it "knows valid code" do
      expect(
        CodeNode.valid? <<~EOM
          describe "foo" do
          end
        EOM
      ).to be_truthy

      expect(
        CodeNode.valid? <<~EOM
          describe "foo"
          end
        EOM
      ).to be_falsey
    end
  end
end

class CodeSource
  attr_reader :lines, :indent_array, :indent_hash, :code_lines

  def initialize(source)
    @frontier = []
    @lines = source.lines
    @indent_array = []
    @indent_hash = Hash.new {|h, k| h[k] = [] }

    @code_lines = []
    lines.each_with_index do |line, i|
      code_line = CodeLine.new(
        line: line,
        index: i,
      )

      @indent_array[i] = code_line.indent
      @indent_hash[code_line.indent] << i
      @code_lines << code_line
    end
  end

  def largest_indent
    @indent_hash.keys.sort.last
  end

  def indent_hash
    @indent_hash
  end

  def self.code_lines_to_source(source)
    source = source.select(&:visible?)
    source = source.join($/)
  end

  def self.valid?(source)
    source = code_lines_to_source(source) if source.is_a?(Array)
    source = source.to_s

    # Parser writes to stderr even if you catch the error
    #
    stderr = $stderr
    $stderr = StringIO.new

    Parser::CurrentRuby.parse(source)
    true
  rescue Parser::SyntaxError
    false
  ensure
    $stderr = stderr if stderr
  end

# def next_frontier
  #   return @frontier.sort(&:max_indent).pop if @frontier.any?

  #   indent = self.largest_indent
  #   if (line = @indent_hash[indent].pop)
  #     block = CodeBlock.new(
  #       source: source,
  #       lines: line
  #     ).block_with_neighbors_while do |l|
  #       l.indent == line.indent
  #     end

  #     @indent_hash[indent] -= block.lines
  #     @indent_hash.delete(indent) if @indent_hash[indent].empty?
  #   end
  # end

  # def detect_invalid
  #   while block = next_frontier
  #     if frontier.empty?
  #       line = @indent_hash[indent].pop
  #       block = CodeBlock.new(
  #         source: source,
  #         lines: line
  #       ).block_with_neighbors_while do |l|
  #         l.indent == line.indent
  #       end

  #       @indent_hash[indent] -= block.lines
  #     else
  #       block = frontier.sort(&:max_indent).pop # Look at highest
  #     end

  #     if block.valid?
  #       # Valid lines can be ignored, keep searching
  #       block.lines.each(&:mark_invisible)
  #     else
  #       if block.document_valid_without?
  #         block.lines.each(&:mark_invalid)

  #         # Mark invalid
  #         # return globally invalid
  #         return
  #       else
  #         next_indent = block.closest_inden
  #         frontier << block.block_with_neighbors_while do |l|
  #           l.indent = next_indent
  #         end
  #       end
  #     end
  #   end
  # end
end

class DetectInvalid
  def initialize
    @source = source
  end

  def call
  end
end

class CodeLine
  attr_reader :line, :index, :indent

  VALID_STATUS = [:valid, :invalid, :unknown].freeze

  def initialize(line: , index:)
    @line = line
    @stripped_line = line.strip
    @index = index
    @indent = SpaceCount.indent(line)
    @is_end = line.strip == "end".freeze
    @status = nil # valid, invalid, unknown
    @visible = true
  end

  def mark_valid
    @status = :valid
  end

  def mark_invalid
    @status = :invalid
  end

  def mark_invisible
    @visible = false
  end

  def mark_visible
    @visible = true
  end

  def visible?
    @visible
  end

  def line_number
    index + 1
  end

  def not_empty?
    !empty?
  end

  def empty?
    @stripped_line.empty?
  end

  def to_s
    @line
  end

  def is_end?
    @is_end
  end
end


class CodeBlock
  attr_reader :lines

  def initialize(source: , lines: [])
    @lines = Array(lines)
    @source = source
  end

  def max_indent
    @lines.map(&:indent).max
  end

  def block_with_neighbors_while
    array = []
    array << before_lines.take_while do |line|
      yield line
    end
    array << lines

    array << after_lines.take_while do |line|
      yield line
    end

    CodeBlock.new(
      source: @source,
      lines: array.flatten
    )
  end

  def closest_indent
    [before_line.indent, after_line.indent].max
  end

  def before_line
    before_lines.first
  end

  def after_line
    after_lines.first
  end

  def before_lines
    index = @lines.first.index - 1
    @source.code_lines[index..0]
      .select(&:not_empty?)
      .select(&:visible?)
      .reverse
  end

  def after_lines
    index = @lines.last.index + 1
    @source.code_lines[index..-1]
      .select(&:not_empty?)
      .select(&:visible?)
  end

  # Returns a code block of the source that does not include
  # the current lines. This is useful for checking if a source
  # with the given lines removed parses successfully. If so
  #
  # Then it's proof that the current block is invalid
  def block_without
    @block_without ||= CodeBlock.new(
      source: @source,
      lines: @source.code_lines - @lines
    )
  end

  def document_valid_without?
    block_without.valid?
  end

  def valid?
    CodeSource.valid?(self.to_s)
  end

  def to_s
    CodeSource.code_lines_to_source(@lines)
  end
end

# if frontier.empty?
#   line = @indent_hash[indent].pop
#   block = CodeBlock.new(
#     source: source,
#     lines: line
#   ).block_with_neighbors_while do |l|
#     l.indent == line.indent
#   end

#   @indent_hash[indent] -= block.lines
# else
#   block = frontier.sort(&:max_indent).pop # Look at highest
# end

# if block.valid?
#   # Valid lines can be ignored, keep searching
#   block.lines.each(&:mark_invisible)
# else
#   if block.document_valid_without?
#     block.lines.each(&:mark_invalid)

#     # Mark invalid
#     # return globally invalid
#     return
#   else
#     next_indent = block.closest_inden
#     frontier << block.block_with_neighbors_while do |l|
#       l.indent = next_indent
#     end
#   end
# end

RSpec.describe CodeLine do
  it "code block can detect if it's valid or not" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM

    block = CodeBlock.new(source: source, lines: source.code_lines[1])
    expect(block.valid?).to be_truthy
    expect(block.document_valid_without?).to be_truthy
    expect(block.block_without.lines).to eq([source.code_lines[0], source.code_lines[2]])
    expect(block.max_indent).to eq(2)
    expect(block.before_lines).to eq([source.code_lines[0]])
    expect(block.after_lines).to eq([source.code_lines[2]])
    expect(
      block.block_with_neighbors_while {|n| n.indent == block.max_indent - 2}.lines
    ).to eq(source.code_lines)

    expect(
      block.block_with_neighbors_while {|n| n.index == 1 }.lines
    ).to eq([source.code_lines[1]])


#   block = CodeBlock.new(
#     source: source,
#     lines: line
#   ).block_with_neighbors_while do |l|
#     l.indent == line.indent
#   end

    source = CodeSource.new(<<~EOM)
      def foo
        bar; end
      end
    EOM

    block = CodeBlock.new(source: source, lines: source.code_lines[1])
    expect(block.valid?).to be_falsey
    expect(block.document_valid_without?).to be_truthy
    expect(block.block_without.lines).to eq([source.code_lines[0], source.code_lines[2]])
    expect(block.before_lines).to eq([source.code_lines[0]])
    expect(block.after_lines).to eq([source.code_lines[2]])
  end

  it "ignores marked valid lines" do
    code_lines = []
    code_lines << CodeLine.new(line: "def foo",            index: 0)
    code_lines << CodeLine.new(line: "  Array(value) |x|", index: 1)
    code_lines << CodeLine.new(line: "  end",              index: 2)
    code_lines << CodeLine.new(line: "end",                index: 3)

    expect(CodeSource.valid?(code_lines)).to be_falsey
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM.strip)
      def foo
        Array(value) |x|
        end
      end
    EOM

    code_lines[0].mark_invisible
    code_lines[3].mark_invisible

    expected = ["  Array(value) |x|", "  end"].join($/)
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(expected)

    expect(CodeSource.valid?(code_lines)).to be_falsey
  end

  it "ignores marked invalid lines" do
    code_lines = []
    code_lines << CodeLine.new(line: "def foo",            index: 0)
    code_lines << CodeLine.new(line: "  Array(value) |x|", index: 1)
    code_lines << CodeLine.new(line: "  end",              index: 2)
    code_lines << CodeLine.new(line: "end",                index: 3)

    expect(CodeSource.valid?(code_lines)).to be_falsey
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM.strip)
      def foo
        Array(value) |x|
        end
      end
    EOM

    code_lines[1].mark_invisible
    code_lines[2].mark_invisible

    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM.strip)
      def foo
      end
    EOM

    expect(CodeSource.valid?(code_lines)).to be_truthy
  end


  it "empty code line" do
    source = CodeSource.new(<<~EOM)
      # Not empty

      # Not empty
    EOM

    expect(source.code_lines.map(&:empty?)).to eq([false, true, false])
    expect(source.code_lines.map {|l| CodeSource.valid?(l) }).to eq([true, true, true])
  end

  it "blerg" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM

    expect(source.indent_array).to eq([0, 2, 0])
    expect(source.indent_hash).to eq({0 =>[0, 2], 2 =>[1]})
    expect(source.code_lines.join()).to eq(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
  end
end
