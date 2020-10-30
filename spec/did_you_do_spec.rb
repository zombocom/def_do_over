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
      string.split(/\w/).first.length
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
    it "suggests syntax" do
      io = StringIO.new
      source = <<~EOM
       Array(value).each |x|
       end

       # I'm fine

       begon
         Foo.call
       rescue
       end
      EOM
      SuggestSyntax.new(source, io: io).call

      expect(io.string).to eq(<<~EOM)
        Array(value).each |x| #{CodeNode::SYNTAX_SUGGESTION}
        end

        begin
        rescue #{CodeNode::SYNTAX_SUGGESTION}
        end
      EOM
    end

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
