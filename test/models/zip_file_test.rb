require "test_helper"

class ZipFileTest < ActiveSupport::TestCase
  test "creating a zip attaches what the block writes" do
    export = exports(:pending_account_export)

    ZipFile.create_for(export.file, filename: "export.zip") { |zip| zip.add_file("hello.txt", "Hello, World!") }

    assert export.file.attached?
    assert_equal "export.zip", export.file.filename.to_s
    assert_equal "application/zip", export.file.content_type

    ZipFile.read_from(export.file.blob) do |zip|
      assert_equal "Hello, World!", zip.read("hello.txt")
    end
  end

  test "creating a zip needs a block" do
    error = assert_raises(ArgumentError) { ZipFile.create_for(exports(:pending_account_export).file, filename: "export.zip") }
    assert_equal "No block given", error.message
  end

  test "reading a zip needs a block" do
    export = exports(:pending_account_export)
    ZipFile.create_for(export.file, filename: "export.zip") { |zip| zip.add_file("hello.txt", "Hello, World!") }

    error = assert_raises(ArgumentError) { ZipFile.read_from(export.file.blob) }
    assert_equal "No block given", error.message
  end
end
