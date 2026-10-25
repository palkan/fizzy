class ZipFile::Reader::IO
  # @rbs @entry: ZipKit::FileReader::ZipEntry
  # @rbs @io: ZipFile::Reader::_IO
  # @rbs @extractor: ZipKit::FileReader::_Extractor

  #: (ZipKit::FileReader::ZipEntry, ZipFile::Reader::_IO) -> void
  def initialize(entry, io)
    @entry = entry
    @io = io
    @extractor = @entry.extractor_from(@io)
  end

  #: (?Integer?, ?String?) -> String?
  def read(length = nil, buffer = nil)
    return nil if @extractor.eof?

    data = @extractor.extract(length)
    return nil if data.nil?

    if buffer
      buffer.replace(data)
      buffer
    else
      data
    end
  end

  #: () -> bool
  def eof?
    @extractor.eof?
  end

  #: () -> Integer
  def rewind
    @extractor = @entry.extractor_from(@io)
    0
  end

  #: () -> Integer
  def size
    @entry.uncompressed_size
  end
end
