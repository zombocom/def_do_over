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

      hash = {}
      @source.each_line.with_index do |line, i|
        next unless line.strip == "end"
        spaces = line.split(/\w/).first.length
        hash[spaces] ||= []
        hash[spaces] << i
      end

      indent = hash.keys.min
      @array = hash[indent]
    end

    def length
      @array.length
    end
  end

  it "blerg" do

    source = <<~EOM
      describe "things" do
      end

      describe "next" do
      end
    EOM

    out = ParseEndZones.new(source)
    expect(out.length).to eq(2)
  end
end
