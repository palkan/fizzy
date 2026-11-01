require "test_helper"

class ZipFile::WriterTest < ActiveSupport::TestCase
  test "writer adds files with content" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("hello.txt", "Hello, World!")
    writer.close

    assert writer.exists?("hello.txt")
    assert_not writer.exists?("missing.txt")
  end

  test "writer adds files with block" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("hello.txt") { |sink| sink.write("Hello, World!") }
    writer.close

    assert writer.exists?("hello.txt")
  end

  test "writer counts the size and checksum of what it streams" do
    io = StringIO.new(+"".b)

    writer = ZipFile::Writer.new
    writer.stream_to(io)
    writer.add_file("hello.txt", "Hello, World!")
    writer.close

    assert_equal io.string.bytesize, writer.byte_size
    assert_equal Digest::MD5.base64digest(io.string), writer.checksum
  end

  test "writer counts the size and checksum of what it writes to a file" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("hello.txt", "Hello, World!")
    writer.close

    tempfile.rewind
    contents = tempfile.read
    assert_equal contents.bytesize, writer.byte_size
    assert_equal Digest::MD5.base64digest(contents), writer.checksum
  end

  test "writer globs entries" do
    tempfile = Tempfile.new([ "test", ".zip" ])
    tempfile.binmode

    writer = ZipFile::Writer.new(tempfile)
    writer.add_file("docs/readme.txt", "Readme")
    writer.add_file("docs/guide.txt", "Guide")
    writer.add_file("images/logo.png", "PNG data")
    writer.close

    assert_equal [ "docs/guide.txt", "docs/readme.txt" ], writer.glob("docs/*.txt")
    assert_equal [ "images/logo.png" ], writer.glob("**/*.png")
  end
end
