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

  class ParseEndZones
    def initialize(source)
      @source = source
      @array = []

      count_line_array = []
      space_count_end_index_hash = Hash.new {|h, k| h[k] = [] }
      @lines = @source.lines
      @lines.each.with_index do |line, i|
        count = line.split(/\w/).first.length
        count_line_array << count

        next unless line.strip == "end"
        space_count_end_index_hash[count] << i
      end


      # start at the last end, and search up until finding a line that matches
      # indentation
      end_levels = space_count_end_index_hash.keys.sort
      spaces = end_levels[0]

      space_count_end_index_hash[spaces].each do |end_index|
        middle = []
        beginning = nil

        end_index.pred.downto(0).each do |i|
          line = @lines[i]

          if count_line_array[i] == spaces
            beginning = line
            break
          else
            middle << line
          end
        end

        @array << {ending: @lines[end_index], beginning: beginning, middle: middle.reverse.join($/)}
      end
    end

    def length
      @array.length
    end

    def to_array
      @array
    end
  end

  it "blerg" do
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
