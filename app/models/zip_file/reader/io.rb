# typed: true

class ZipFile::Reader::IO
  #: (ZipKit::FileReader::ZipEntry, ZipFile::Reader::Source) -> void
  def initialize(entry, io)
    @entry = entry #: ZipKit::FileReader::ZipEntry
    @io = io #: ZipFile::Reader::Source
    @extractor = @entry.extractor_from(@io) #: ZipKit::FileReader::StoredReader | ZipKit::FileReader::InflatingReader
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
