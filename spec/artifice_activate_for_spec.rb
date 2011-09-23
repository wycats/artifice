require "net/http"

shared_examples_for "a working request to google.ca" do
  it "gets response headers" do
    @response["Content-Type"].should  == "text/html"
  end

  it "sends the host properly" do
    @response["X-Test-Host"].should == "google.ca"
  end
end

shared_examples_for "a working GET request to google.ca" do
  it_should_behave_like "a working request to google.ca"

  it "sends the method properly" do
    @response["X-Test-Method"].should == "GET"
  end
end

shared_examples_for "a working POST request to google.ca" do
  it_should_behave_like "a working request to google.ca"

# it "sends the method properly" do
#   @response["X-Test-Method"].should == "POST"
# end

# it "sends the input properly" do
#   @response["X-Test-Input"].should == "foo=bar"
# end
end

shared_examples_for "a working HTTP request to google.ca" do
  it "sends the scheme properly" do
    @response["X-Test-Scheme"].should == "http"
  end

  it "sends the port properly" do
    @response["X-Test-Port"].should == "80"
  end
end

shared_examples_for "a working HTTPS request to google.ca" do
  it "sends the scheme properly" do
    @response["X-Test-Scheme"].should == "https"
  end

  it "sends the port properly" do
    @response["X-Test-Port"].should == "443"
  end
end

describe "Artifice#activate_for" do
  NET_HTTP = ::Net::HTTP
  TCP_SOCKET = ::TCPSocket

  FakeApp = proc do |env|
    [200, {"Content-Type"  => "text/html",
           "X-Test-Method" => env["REQUEST_METHOD"],
           "X-Test-Input"  => env["rack.input"].read,
           "X-Test-Scheme" => env["rack.url_scheme"],
           "X-Test-Host"   => env["SERVER_NAME"],
           "X-Test-Port"   => env["SERVER_PORT"]},
      ["Hello world"]
    ]
  end

  def replace_tcpsocket(value)
    ::Object.class_eval do
      remove_const(:TCPSocket)
      const_set(:TCPSocket, value)
    end
  end

  def mock_socket(form, method, host, port = 80, scheme = "http")
    fullhost = host
    fullhost = "#{fullhost}:#{port}" if port != 80
    headers = Data[form][:request_headers] % [ method, fullhost ]
    body = Data[form][:request_body]
    response = Data[form][:response] % [ method, body, scheme, host, port ]

    tcp_socket = double("TCPSocket #{form}/#{method}/#{host}")

    socket = double("socket #{form}/#{method}/#{host}")

    socket.should_receive(:closed?).and_return(false)
    socket.should_receive(:write).with(headers).and_return(headers.size)
    socket.should_receive(:write).with(body).and_return(body.size) if body
    socket.should_receive(:sysread).with(16384).and_return(response)
    socket.should_receive(:closed?).and_return(false)
    socket.should_receive(:close)
    socket.should_receive(:closed?).and_return(true)

    tcp_socket.should_receive(:open).with(host, port).and_return(socket)
    replace_tcpsocket(tcp_socket)
  end

  post_with_block = {
    :request_headers  =>
      [ "%s /index HTTP/1.1", "Accept: */*",
        "Content-Type: application/x-www-form-urlencoded",
        "Content-Length: 7", "Host: %s", "", "" ].join("\r\n"),
    :request_body     => "foo=bar",
    :response         =>
      [ "HTTP/1.1 200 OK", "Content-Type: text/html",
        "X-Test-Method: %s", "X-Test-Input: %s",
        "X-Test-Scheme: %s", "X-Test-Host: %s",
        "X-Test-Port: %s",
        "Content-Length: 11", "", "Hello world" ].join("\n"),
  }

  post_without_block = {
    :request_headers  =>
      [ "%s /index HTTP/1.1", "Accept: */*",
        "Content-Type: application/x-www-form-urlencoded",
        "Connection: close", "Content-Length: 7",
        "Host: %s", "", "" ].join("\r\n"),
    :request_body     => "foo=bar",
    :response         =>
      [ "HTTP/1.1 200 OK", "Content-Type: text/html",
        "X-Test-Method: %s", "X-Test-Input: %s",
        "X-Test-Scheme: %s", "X-Test-Host: %s",
        "X-Test-Port: %s",
        "Content-Length: 11", "", "Hello world" ].join("\n"),
  }

  get = {
    :request_headers  =>
      [ "%s /get HTTP/1.1", "Accept: */*",
        "Connection: close",
        "Host: %s", "", "" ].join("\r\n"),
    :response         =>
      [ "HTTP/1.1 200 OK", "Content-Type: text/html",
        "X-Test-Method: %s", "X-Test-Input: %s",
        "X-Test-Scheme: %s", "X-Test-Host: %s",
        "X-Test-Port: %s",
        "Content-Length: 11", "", "Hello world" ].join("\n"),
  }

  Data = {
    :post_with_block    => post_with_block,
    :post_without_block => post_without_block,
    :get                => get,
  }

  DoubleData = [
    [ 16384, "HTTP/1.1 200 OK\nContent-Type: text/html\nContent-Length: 11\n\nHello world" ],
  ]

  require "artifice"

  describe "before activating" do
    it "does not override Net::HTTP" do
      ::Net::HTTP.should == NET_HTTP
    end
  end

  describe "when activating for google.com without a block" do
    after do
      Artifice.deactivate
      ::Net::HTTP.should == NET_HTTP
      replace_tcpsocket(TCP_SOCKET)
    end

    before do
      Artifice.activate_for(FakeApp, "google.com")
    end

    it "replaces Net::HTTP" do
      ::Net::HTTP.should_not == NET_HTTP
    end

    describe "and making a POST request to google.ca with Net::HTTP.start {}" do
      before do
        mock_socket(:post_with_block, "POST", "google.ca")

        @response = Net::HTTP.start("google.ca", 80) do |http|
          http.post("/index", "foo=bar")
        end
      end

#     it_should_behave_like "a working POST request to google.ca"
#     it_should_behave_like "a working HTTP request to google.ca"
    end

    describe "and making a POST request to google.ca with Net::HTTP.start" do

      before do
        mock_socket(:post_without_block, "POST", "google.ca", 443, "https")

        http = Net::HTTP.new("google.ca", 443)

        # Can't use http.use_ssl here; it breaks the mocks.
        # http.use_ssl = true
        @response = http.post("/index", "foo=bar")
      end

      it_should_behave_like "a working POST request to google.ca"
      it_should_behave_like "a working HTTPS request to google.ca"
    end

    describe "and make a GET request with Net::HTTP.start" do
      before do
        mock_socket(:get, "GET", "google.ca")

        http = Net::HTTP.new("google.ca", 80)
        @response = http.get("/get")
      end

      it_should_behave_like "a working GET request to google.ca"
      it_should_behave_like "a working HTTP request to google.ca"
    end

#   describe "and make a GET request with Net::HTTP.get_response" do
#     before do
#       mock_socket(:get, "GET", "google.ca")
    #       no connection: close
#       @response = Net::HTTP.get_response(URI.parse("http://google.ca/get"))
#     end

#     it_should_behave_like "a working GET request to google.ca"
#     it_should_behave_like "a working HTTP request to google.ca"
#   end

#   describe "and make a GET request with Net::HTTP::Get.new" do
#     before do
#       Net::HTTP.start('google.ca') do |http|
#         req = Net::HTTP::Get.new('/get')
#         @response = http.request(req)
#       end
#     end

#     it_should_behave_like "a working GET request to google.ca"
#     it_should_behave_like "a working HTTP request to google.ca"
#   end
#   
#   describe "and make a POST request with Net::HTTP::Post.new" do
#     before do
#       Net::HTTP.start('google.ca') do |http|
#         req = Net::HTTP::Post.new('/index')
#         req.body = 'foo=bar'
#         @response = http.request(req)
#       end
#     end

#     it_should_behave_like "a working POST request to google.ca"
#     it_should_behave_like "a working HTTP request to google.ca"
#   end
  end

# describe "when activating with a block" do
#   
#   before do
#     ::Net::HTTP.should == NET_HTTP
#   end

#   after do
#     ::Net::HTTP.should == NET_HTTP
#   end

#   it "deactivates automatically after the block is executed" do
#     Artifice.activate_with( lambda {} ) do
#       ::Net::HTTP.should == Artifice::Net::HTTP
#     end
#   end

#   it "deactivates even if an exception is raised from within the block" do
#     lambda {
#       Artifice.activate_with( lambda {} ) do
#         ::Net::HTTP.should == Artifice::Net::HTTP
#         raise 'Boom!'
#       end
#     }.should raise_error
#   end
# end
end
