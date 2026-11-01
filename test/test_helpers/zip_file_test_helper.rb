module ZipFileTestHelper
  private
    def create_test_zip(files)
      tempfile = Tempfile.new([ "test", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      files.each { |path, content| writer.add_file(path, content) }
      writer.close

      tempfile.rewind
      tempfile
    end

    def zip_of(files)
      ZipFile::Reader.new(create_test_zip(files))
    end

    def written_zip
      tempfile = Tempfile.new([ "test", ".zip" ])
      tempfile.binmode

      writer = ZipFile::Writer.new(tempfile)
      yield writer
      writer.close

      tempfile.rewind
      ZipFile::Reader.new(tempfile)
    end
end
