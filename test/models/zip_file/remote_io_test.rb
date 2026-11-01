require "test_helper"

class ZipFile::RemoteIOTest < ActiveSupport::TestCase
  include ZipFileTestHelper

  URL = "https://storage.example.com/export.zip"

  setup do
    @zip = create_test_zip("hello.txt" => "Hello, World!").read
  end

  test "reads a zip one range at a time" do
    serve_ranges_of @zip

    reader = ZipFile::Reader.new(ZipFile::RemoteIO.new(URL))
    assert_equal "Hello, World!", reader.read("hello.txt")
  end

  test "takes the size from the range it was sent" do
    serve_ranges_of @zip

    assert_equal @zip.bytesize, ZipFile::RemoteIO.new(URL).size
    assert_requested :get, URL, headers: { "Range" => "bytes=0-0" }
  end

  test "takes the size from the whole object when ranges aren't supported" do
    stub_request(:get, URL).to_return(status: 200, body: @zip, headers: { "Content-Length" => @zip.bytesize.to_s })

    assert_equal @zip.bytesize, ZipFile::RemoteIO.new(URL).size
  end

  test "an unexpected reply to the size request is an error" do
    stub_request(:get, URL).to_return(status: 403)

    error = assert_raises(RuntimeError) { ZipFile::RemoteIO.new(URL).size }
    assert_equal "Remote at #{URL} replied with code 403", error.message
  end

  test "an unexpected reply to a range request is an error" do
    stub_request(:get, URL).with { it.headers["Range"] == "bytes=0-0" }
      .to_return(status: 206, headers: { "Content-Range" => "bytes 0-0/#{@zip.bytesize}" }, body: @zip.byteslice(0, 1))
    stub_request(:get, URL).with { it.headers["Range"] != "bytes=0-0" }.to_return(status: 500)

    error = assert_raises(RuntimeError) { ZipFile::Reader.new(ZipFile::RemoteIO.new(URL)) }
    assert_equal "Remote at #{URL} replied with code 500", error.message
  end

  test "verifies the peer by default" do
    serve_ranges_of @zip
    Net::HTTP.any_instance.expects(:verify_mode=).never

    ZipFile::RemoteIO.new(URL).size
  end

  test "skips verifying the peer when told to" do
    serve_ranges_of @zip
    Net::HTTP.any_instance.expects(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE).at_least_once

    ZipFile::RemoteIO.new(URL, ssl_verify_peer: false).size
  end

  private
    def serve_ranges_of(body)
      stub_request(:get, URL).to_return do |request|
        first, last = request.headers["Range"].delete_prefix("bytes=").split("-").map(&:to_i)
        last = [ last, body.bytesize - 1 ].min

        { status: 206, body: body.byteslice(first..last), headers: { "Content-Range" => "bytes #{first}-#{last}/#{body.bytesize}" } }
      end
    end
end
