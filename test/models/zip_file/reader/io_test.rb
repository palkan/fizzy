require "test_helper"

class ZipFile::Reader::IOTest < ActiveSupport::TestCase
  include ZipFileTestHelper

  test "reader io provides size" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    reader.read("hello.txt") do |io|
      assert_equal 13, io.size
    end
  end

  test "reader io supports rewind" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    reader = ZipFile::Reader.new(tempfile)
    reader.read("hello.txt") do |io|
      first_read = io.read
      io.rewind
      second_read = io.read

      assert_equal first_read, second_read
    end
  end

  test "reader io reads into a given buffer" do
    tempfile = create_test_zip("hello.txt" => "Hello, World!")

    ZipFile::Reader.new(tempfile).read("hello.txt") do |io|
      buffer = +"previous contents"

      assert_same buffer, io.read(nil, buffer)
      assert_equal "Hello, World!", buffer
    end
  end

  test "reader io reads nothing once it's at the end" do
    tempfile = create_test_zip("hello.txt" => "Hello")

    ZipFile::Reader.new(tempfile).read("hello.txt") do |io|
      io.read

      assert_nil io.read
      assert_nil io.read(5, +"")
    end
  end

  test "reader io tracks eof" do
    tempfile = create_test_zip("hello.txt" => "Hello")

    reader = ZipFile::Reader.new(tempfile)
    reader.read("hello.txt") do |io|
      assert_not io.eof?
      io.read
      assert io.eof?
    end
  end
end
