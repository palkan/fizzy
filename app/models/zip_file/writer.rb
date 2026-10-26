# typed: true

class ZipFile::Writer
  #: Integer
  attr_reader :byte_size

  #: (?ZipFile::Writer::Output?) -> void
  def initialize(io = nil)
    @entries = [] #: Array[String]
    @byte_size = 0
    @output_io = io #: ZipFile::Writer::Output?
    @streamer = nil #: ZipKit::Streamer?
    @digest = Digest::MD5.new #: Digest::MD5
  end

  #: (ZipFile::Writer::Output) -> void
  def stream_to(io)
    @output_io = io
  end

  #: (String) -> Integer
  def write(data)
    # Set by initialize or stream_to before writing
    output_io = @output_io #: as !nil
    output_io.write(data)
    @byte_size += data.bytesize
    @digest.update(data)
    data.bytesize
  end

  # Writes the content, or streams it from the block when given one
  #: (String, ?String?, ?compress: bool) ?{ (ZipKit::Streamer::Writable) -> void } -> void
  def add_file(path, content = nil, compress: true, &block)
    @entries << path
    write_method = compress ? :write_deflated_file : :write_stored_file

    if block_given?
      streamer.public_send(write_method, path) { |sink| yield sink }
    else
      streamer.public_send(write_method, path) { |sink| sink.write(content) }
    end
  end

  #: (String) -> Array[String]
  def glob(pattern)
    @entries.select { |e| File.fnmatch(pattern, e) }.sort
  end

  #: (String) -> bool
  def exists?(path)
    @entries.include?(path)
  end

  #: () -> void
  def close
    streamer.close
  end

  #: () -> String
  def checksum
    Base64.strict_encode64(@digest.digest)
  end

  private
    #: () -> ZipKit::Streamer
    def streamer
      @streamer ||= ZipKit::Streamer.new(@output_io)
    end
end
