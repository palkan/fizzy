class ZipFile::Writer
  # @rbs @entries: Array[String]
  # @rbs @output_io: ZipFile::Writer::_Output?
  # @rbs @streamer: ZipKit::Streamer?
  # @rbs @digest: Digest::MD5

  attr_reader :byte_size #: Integer

  #: (?ZipFile::Writer::_Output?) -> void
  def initialize(io = nil)
    @entries = [] #: Array[String]
    @byte_size = 0
    @output_io = io
    @streamer = nil
    @digest = Digest::MD5.new
  end

  #: (ZipFile::Writer::_Output) -> void
  def stream_to(io)
    @output_io = io
  end

  #: (String) -> Integer
  def write(data)
    # Set by initialize or stream_to before writing
    output_io = @output_io #: ZipFile::Writer::_Output
    output_io.write(data)
    @byte_size += data.bytesize
    @digest.update(data)
    data.bytesize
  end

  # @rbs (String, String, ?compress: bool) -> void
  #    | (String, ?nil, ?compress: bool) { (ZipKit::Streamer::Writable) -> void } -> void
  def add_file(path, content = nil, compress: true)
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
