# typed: true

class ZipFile::Reader
  #: (ZipFile::Reader::Source) -> void
  def initialize(io)
    @io = io #: ZipFile::Reader::Source
    @reader = ZipKit::FileReader.new.read_zip_structure(io: io) #: Array[ZipKit::FileReader::ZipEntry]
  rescue ZipKit::FileReader::ReadError, ZipKit::FileReader::MissingEOCD, ZipKit::FileReader::UnsupportedFeature => e
    raise ZipFile::InvalidFileError, e.message
  end

  # Returns the file's content, or the block's result when given a block
  #: [T] (String) ?{ (ZipFile::Reader::IO) -> T } -> (String | T)
  def read(file_path, &block)
    entry = @reader.find { |e| e.filename == file_path }
    raise ArgumentError, "File not found in zip: #{file_path}" unless entry
    raise ArgumentError, "Cannot read directory entry: #{file_path}" if entry.filename.end_with?("/")

    if block_given?
      yield ZipFile::Reader::IO.new(entry, @io)
    else
      entry.extractor_from(@io).extract #: as String
    end
  end

  #: (String) -> Array[String]
  def glob(pattern)
    @reader.map(&:filename).select { |name| File.fnmatch(pattern, name) }.sort
  end

  #: (String) -> bool
  def exists?(file_path)
    @reader.any? { |e| e.filename == file_path }
  end
end
