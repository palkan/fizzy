require "test_helper"

class ZipFile::ReaderTest < ActiveSupport::TestCase
  include ZipFileTestHelper

  test "reader reads file content" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    content = reader.read("hello.txt")

    assert_equal "Hello, World!", content
  end

  test "reader reads file with block" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    content = nil
    reader.read("hello.txt") { |io| content = io.read }

    assert_equal "Hello, World!", content
  end

  test "reader raises for missing file" do
    tempfile = create_test_zip("hello.txt" => "Hello")

    reader = ZipFile::Reader.new(tempfile)

    assert_raises(ArgumentError) { reader.read("missing.txt") }
  end

  test "reader refuses to read a directory" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode
    ZipKit::Streamer.open(tempfile) { |zip| zip.add_empty_directory(dirname: "docs") }
    tempfile.rewind

    error = assert_raises(ArgumentError) { ZipFile::Reader.new(tempfile).read("docs/") }
    assert_equal "Cannot read directory entry: docs/", error.message
  end

  test "reader checks file existence" do
    tempfile = create_test_zip("hello.txt" => "Hello")

    reader = ZipFile::Reader.new(tempfile)

    assert reader.exists?("hello.txt")
    assert_not reader.exists?("missing.txt")
  end

  test "reader globs entries" do
    tempfile = create_test_zip(
      "docs/readme.txt" => "Readme",
      "docs/guide.txt" => "Guide",
      "images/logo.png" => "PNG"
    )

    reader = ZipFile::Reader.new(tempfile)

    assert_equal [ "docs/guide.txt", "docs/readme.txt" ], reader.glob("docs/*.txt")
  end

  test "reader raises InvalidFileError for non-zip file" do
    tempfile = Tempfile.new([ "not_a_zip", ".zip" ])
    tempfile.write("this is not a zip file at all")
    tempfile.rewind

    assert_raises(ZipFile::InvalidFileError) { ZipFile::Reader.new(tempfile) }
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
