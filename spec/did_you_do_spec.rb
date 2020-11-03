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

  #describe "integration" do
  #  it "finds nested nodes" do

  #    invalid_nodes = []
  #    ParseEndZones.new(source).each do |zone|
  #      CodeNode.new(
  #        beginning: zone[:beginning],
  #        middle: zone[:middle],
  #        ending: zone[:ending],
  #        invalid_nodes: invalid_nodes
  #      ).call
  #    end

  #    expect(invalid_nodes.length).to eq(2)
  #    expect(invalid_nodes.first.full_source).to include(%Q{describe "lol"})
  #    expect(invalid_nodes.first.full_source).to eq(<<~EOM.strip)
  #     describe "lol" #{CodeNode::SYNTAX_SUGGESTION}
  #     end
  #    EOM
  #    expect(invalid_nodes.last.full_source).to include(%Q{  Foo.call})

  #    expect(invalid_nodes.last.full_source).to eq(<<~EOM.strip)
  #     describe "hi" do
  #       Foo.call #{CodeNode::SYNTAX_SUGGESTION}
  #       end
  #     end
  #    EOM
  #  end
  #end

  #describe "code node" do
  #  it "finds invalid sub nodes" do
  #    invalid_nodes = []
  #    node = CodeNode.new(
  #      beginning: "def foo",
  #      middle:    "  bar\n  end",
  #      ending:    "end",
  #      invalid_nodes: invalid_nodes,
  #    )
  #    node.call

  #    expect(invalid_nodes.length).to eq(1)
  #    expect(invalid_nodes.first).to_not eq(node)
  #    expect(invalid_nodes.first.full_source).to eq(<<~EOM.strip)
  #      def foo
  #        bar #{CodeNode::SYNTAX_SUGGESTION}
  #        end
  #      end
  #    EOM
  #  end

  #  it "likes valid code" do
  #    invalid_nodes = []
  #    node = CodeNode.new(
  #      beginning: "def foo",
  #      middle:    "  puts 'lol'",
  #      ending:    "end",
  #      invalid_nodes: invalid_nodes,
  #    )
  #    node.call

  #    expect(invalid_nodes.length).to eq(0)
  #  end

  #  it "finds invalid empty code" do
  #    invalid_nodes = []
  #    node = CodeNode.new(
  #      beginning: "defzfoo",
  #      middle:    "  puts 'lol'",
  #      ending:    "end",
  #      invalid_nodes: invalid_nodes,
  #    )
  #    node.call

  #    expect(invalid_nodes.length).to eq(1)
  #    expect(invalid_nodes.first).to eq(node)
  #    expect(invalid_nodes.first.full_source).to eq(<<~EOM.strip)
  #      defzfoo #{CodeNode::SYNTAX_SUGGESTION}
  #        #{CodeNode::OMITTED}
  #      end
  #    EOM
  #  end

  #  it "wraps code" do
  #    node = CodeNode.new(
  #      beginning: "def foo",
  #      middle:    "  puts 'lol'",
  #      ending:    "end"
  #    )

  #    expect(node.empty_source).to eq(<<~EOM.strip)
  #      def foo
  #      end
  #    EOM

  #    expect(node.full_source).to eq(<<~EOM.strip)
  #      def foo
  #        puts 'lol'
  #      end
  #    EOM
  #  end

  #  it "knows valid code" do
  #    expect(
  #      CodeNode.valid? <<~EOM
  #        describe "foo" do
  #        end
  #      EOM
  #    ).to be_truthy

  #    expect(
  #      CodeNode.valid? <<~EOM
  #        describe "foo"
  #        end
  #      EOM
  #    ).to be_falsey
  #  end
  #end
end

module SpaceCount
  def self.indent(string)
    string.split(/\w/).first&.length || 0
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

  def marked_invalid?
    @status == :invalid
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

  def visible_lines
    @lines
      .select(&:not_empty?)
      .select(&:visible?)
  end

  def max_indent
    visible_lines.map(&:indent).max
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
      @indent_hash[code_line.indent] << code_line
      @code_lines << code_line
    end
  end

  def get_max_indent
    @indent_hash.select! {|k, v| !v.empty?}
    @indent_hash.keys.sort.last
  end

  def indent_hash
    @indent_hash
  end

  def self.code_lines_to_source(source)
    source = source.select(&:visible?)
    source = source.join
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

  def pop_max_indent_line(indent = get_max_indent)
    return nil if @indent_hash.empty?

    if (line = @indent_hash[indent].shift)
      return line
    else
      pop_max_indent_line
    end
  end

  # Returns a CodeBlock based on the maximum indentation
  # present in the source
  def max_indent_to_block
    max_indent = get_max_indent
    if (line = pop_max_indent_line)
      block = CodeBlock.new(
        source: self,
        lines: line
      ).block_with_neighbors_while do |line|
        line.indent == max_indent
      end

      block.lines.each do |line|
        @indent_hash[line.indent].delete(line)
      end
      return block
    end
  end

  # Returns the highest indentation code block from the
  # frontier or if
  def next_frontier
    if @frontier.any?
      block = @frontier.sort(&:max_indent).pop

      if block.max_indent <= self.max_indent
        @frontier.push(block)
        block = nil
      end
    end

    max_indent_to_block if block.nil?
  end

  def invalid_code
    CodeBlock.new(
     lines: code_lines.select(&:marked_invalid?),
     source: self
    )
  end

  def detect_invalid
    while block = next_frontier
      if block.valid?
        block.lines.each(&:mark_valid)
        block.lines.each(&:mark_invisible)
        next
      end

      if block.document_valid_without?
        block.lines.each(&:mark_invalid)
        return
      end

      before_indent = before_line.indent
      after_indent = after_line.indent
      indent = [before_indent, after_indent].max
      @frontier << block.block_with_neighbors_while do |line|
        line.indent == indent
      end
    end
  end
end

RSpec.describe CodeLine do


  it "detect" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
    source.detect_invalid
    expect(source.code_lines.map(&:marked_invalid?)).to eq([false, false, false])

    source = CodeSource.new(<<~EOM)
      def foo
        end
      end
    EOM
    source.detect_invalid
    expect(source.code_lines.map(&:marked_invalid?)).to eq([false, true, false])

    source = CodeSource.new(<<~EOM)
      def foo
        def blerg
      end
    EOM
    source.detect_invalid
    expect(source.code_lines.map(&:marked_invalid?)).to eq([false, true, false])
  end
  it "frontier" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
    block = source.next_frontier
    expect(block.lines).to eq([source.code_lines[1]])

    source.code_lines[1].mark_invisible

    block = source.next_frontier
    expect(block.lines).to eq(
      [source.code_lines[0], source.code_lines[2]])
  end

  it "max indent to block" do
    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
    block = source.max_indent_to_block

    expect(block.lines).to eq([source.code_lines[1]])

    block = source.max_indent_to_block
    expect(block.lines).to eq([source.code_lines[0]])

    source = CodeSource.new(<<~EOM)
      def foo
        puts 'lol'
      end

      def bar
        puts 'boo'
      end
    EOM
    block = source.max_indent_to_block
    expect(block.lines).to eq([source.code_lines[1]])

    block = source.max_indent_to_block
    expect(block.lines).to eq([source.code_lines[5]])
  end

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
    code_lines << CodeLine.new(line: "def foo\n",            index: 0)
    code_lines << CodeLine.new(line: "  Array(value) |x|\n", index: 1)
    code_lines << CodeLine.new(line: "  end\n",              index: 2)
    code_lines << CodeLine.new(line: "end\n",                index: 3)

    expect(CodeSource.valid?(code_lines)).to be_falsey
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM)
      def foo
        Array(value) |x|
        end
      end
    EOM

    code_lines[0].mark_invisible
    code_lines[3].mark_invisible

    expected = ["  Array(value) |x|\n", "  end\n"].join
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(expected)
    expect(CodeSource.valid?(code_lines)).to be_falsey
  end

  it "ignores marked invalid lines" do
    code_lines = []
    code_lines << CodeLine.new(line: "def foo\n",            index: 0)
    code_lines << CodeLine.new(line: "  Array(value) |x|\n", index: 1)
    code_lines << CodeLine.new(line: "  end\n",              index: 2)
    code_lines << CodeLine.new(line: "end\n",                index: 3)

    expect(CodeSource.valid?(code_lines)).to be_falsey
    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM)
      def foo
        Array(value) |x|
        end
      end
    EOM

    code_lines[1].mark_invisible
    code_lines[2].mark_invisible

    expect(CodeSource.code_lines_to_source(code_lines)).to eq(<<~EOM)
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
    # expect(source.indent_hash).to eq({0 =>[0, 2], 2 =>[1]})
    expect(source.code_lines.join()).to eq(<<~EOM)
      def foo
        puts 'lol'
      end
    EOM
  end


  describe "detect cases" do
    it "" do
      source = <<~EOM
        describe "hi" do
          Foo.call
          end
        end

        it "blerg" do
        end
      EOM

      source = CodeSource.new(source)
      source.detect_invalid

      expect(source.code_lines[1].marked_invalid?).to be_truthy
      expect(source.code_lines[2].marked_invalid?).to be_truthy

      expect(source.invalid_code.to_s).to eq("  Foo.call\n  end\n")
    end
  end
end
