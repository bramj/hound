require "attr_extras"
require "rubocop"
require "sentry-raven"

require "fast_spec_helper"
require "app/models/style_guide/base"
require "app/models/style_guide/ruby"
require "app/models/violation"

describe StyleGuide::Ruby, "#violations_in_file" do
  context "with default configuration" do
    describe "for { and } as %r literal delimiters" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
          "test" =~ %r|test|
        CODE
      end
    end

    describe "for private prefix" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
          private def foo
            bar
          end
        CODE
      end
    end

    describe "for trailing commas" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
          _one = [
            1,
          ]
          _two(
            1,
          )
          _three = {
            one: 1,
          }
        CODE
      end
    end

    describe "for single line conditional" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
redirect_to dashboard_path if signed_in?

while signed_in? do something end
        CODE
      end
    end

    describe "for has_* method name" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
def has_something?
  "something"
end
        CODE
      end
    end

    describe "for is_* method name" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
def is_something?
  "something"
end
        CODE
      end
    end

    describe "when using detect" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
users.detect do |user|
  user.active?
end
        CODE
      end
    end

    describe "when using find" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
users.find do |user|
  user.active?
end
        CODE
      end
    end

    describe "when using select" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
users.select do |user|
  user.active?
end
        CODE
      end
    end

    describe "when using find_all" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
users.find_all do |user|
  user.active?
end
        CODE
      end
    end

    describe "when using map" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
users.map do |user|
  user.name
end
        CODE
      end
    end

    describe "when using collect" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
users.collect do |user|
  user.name
end
        CODE
      end
    end

    describe "when using inject" do
      it "returns no violations" do
        expect(violations_in(<<-CODE)).to eq []
          users.inject(0) do |sum, user|
            sum + user.age
          end
        CODE
      end
    end

    describe "when using reduce" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
users.reduce(0) do |result, user|
  user.age
end
        CODE
      end
    end

    context "for long line" do
      it "returns violation" do
        expect(violations_in("a" * 81)).not_to be_empty
      end
    end

    context "for trailing whitespace" do
      it "returns violation" do
        expect(violations_in("one = 1   ")).not_to be_empty
      end
    end

    context "for spaces after (" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
puts( "test")
        CODE
      end
    end

    context "for spaces before )" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
puts("test" )
        CODE
      end
    end

    context "for spaces before ]" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
a["test" ]
        CODE
      end
    end

    context "for private methods indented more than public methods" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
def one
  1
end

private

  def two
    2
  end
        CODE
      end
    end

    context "for leading dot used for multi-line method chain" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
one
  .two
  .three
        CODE
      end
    end

    context "for tab indentation" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
def test
\tputs "test"
end
        CODE
      end
    end

    context "for two methods without newline separation" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
def one
  1
end
def two
  2
end
        CODE
      end
    end

    context "for operator without surrounding spaces" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
two = 1+1
        CODE
      end
    end

    context "for comma without trailing space" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
puts :one,:two
        CODE
      end
    end

    context "for colon without trailing space" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
{one:1}
        CODE
      end
    end

    context "for semicolon without trailing space" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
puts :one;puts :two
        CODE
      end
    end

    context "for opening brace without leading space" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
a ={ one: 1 }
        CODE
      end
    end

    context "for opening brace without trailing space" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
a = {one: 1 }
        CODE
      end
    end

    context "for closing brace without leading space" do
      it "returns violations" do
        expect(violations_in(<<-CODE)).not_to be_empty
a = { one: 1}
        CODE
      end
    end

    context "for method definitions with optional named arguments" do
      it "does not return violations" do
        expect(violations_in(<<-CODE)).to be_empty
def register_email(email:)
  register(email)
end
        CODE
      end
    end

    context "for required keyword arguments" do
      context "without space after arguments" do
        it "returns no violations" do
          code = <<-CODE.strip_heredoc
            def initialize(name:, age:)
              @name = name
              @age = age
            end
          CODE

          expect(violations_in(code)).to be_empty
        end
      end

      context "with spaces after arguments" do
        it "returns violations" do
          code = <<-CODE.strip_heredoc
            def initialize(name: , age: )
              @name = name
              @age = age
            end
          CODE

          violations = violations_in(code)

          expect(violations).to eq [
            "Space found before comma.",
            "Space inside parentheses detected.",
          ]
        end
      end
    end
  end

  context "with custom configuration" do
    it "finds only one violation" do
      config = {
        "StringLiterals" => {
          "EnforcedStyle" => "double_quotes",
          "Enabled" => "true",
        }
      }

      violations = violations_with_config(config)

      expect(violations).to eq ["Use the new Ruby 1.9 hash syntax."]
    end

    it "can use custom configuration to show rubocop cop names" do
      config = { "ShowCopNames" => "true" }

      violations = violations_with_config(config)

      expect(violations).to eq [
        "Style/HashSyntax: Use the new Ruby 1.9 hash syntax."
      ]
    end

    context "with old-style syntax" do
      it "has one violation" do
        config = {
          "StringLiterals" => {
            "EnforcedStyle" => "single_quotes"
          },
          "HashSyntax" => {
            "EnforcedStyle" => "hash_rockets"
          },
        }

        violations = violations_with_config(config)

        expect(violations).to eq [
          "Prefer single-quoted strings when you don't need string "\
          "interpolation or special symbols."
        ]
      end
    end

    context "with excluded files" do
      it "has no violations" do
        config = {
          "AllCops" => {
            "Exclude" => ["lib/a.rb"]
          }
        }

        violations = violations_with_config(config)

        expect(violations).to be_empty
      end
    end

    def violations_with_config(config)
      content = <<-TEXT.strip_heredoc
        def test_method
          { :foo => "hello world" }
        end
      TEXT

      violations_in(content, config)
    end
  end

  private

  def violations_in(content, config = nil)
    repo_config = double("RepoConfig", enabled_for?: true, for: config)
    style_guide = StyleGuide::Ruby.new(repo_config)
    style_guide.violations_in_file(build_file(content)).flat_map(&:messages)
  end

  def build_file(content)
    line = double("Line", content: "blah", number: 1, patch_position: 2)
    double("CommitFile", content: content, filename: "lib/a.rb", line_at: line)
  end
end
