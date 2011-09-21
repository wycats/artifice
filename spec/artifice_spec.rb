require "net/http"

shared_examples_for "a working request" do
  it "gets response headers" do
    @response["Content-Type"].should  == "text/html"
  end

  it "sends the host properly" do
    @response["X-Test-Host"].should == "google.com"
  end
end

shared_examples_for "a working GET request" do
  it_should_behave_like "a working request"

  it "sends the method properly" do
    @response["X-Test-Method"].should == "GET"
  end
end

shared_examples_for "a working POST request" do
  it_should_behave_like "a working request"

  it "sends the method properly" do
    @response["X-Test-Method"].should == "POST"
  end

  it "sends the input properly" do
    @response["X-Test-Input"].should == "foo=bar"
  end
end

shared_examples_for "a working HTTP request" do
  it "sends the scheme properly" do
    @response["X-Test-Scheme"].should == "http"
  end

  it "sends the port properly" do
    @response["X-Test-Port"].should == "80"
  end
end

shared_examples_for "a working HTTPS request" do
  it "sends the scheme properly" do
    @response["X-Test-Scheme"].should == "https"
  end

  it "sends the port properly" do
    @response["X-Test-Port"].should == "443"
  end
end

describe "Artifice" do
  NET_HTTP = ::Net::HTTP

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

  require "artifice"

  describe "before activating" do
    it "does not override Net::HTTP" do
      ::Net::HTTP.should == NET_HTTP
    end
  end

  describe "when activating without a block" do
    after do
      Artifice.deactivate
      ::Net::HTTP.should == NET_HTTP
    end

    before do
      Artifice.activate_with(FakeApp)
    end

    it "replaces Net::HTTP" do
      ::Net::HTTP.should_not == NET_HTTP
    end

    describe "and making a POST request with Net::HTTP.start {}" do
      before do
        @response = Net::HTTP.start("google.com", 80) do |http|
          http.post("/index", "foo=bar")
        end
      end

      it_should_behave_like "a working POST request"
      it_should_behave_like "a working HTTP request"
    end

    describe "and making a POST request with Net::HTTP.start" do
      before do
        http = Net::HTTP.new("google.com", 443)
        http.use_ssl = true
        @response = http.post("/index", "foo=bar")
      end

      it_should_behave_like "a working POST request"
      it_should_behave_like "a working HTTPS request"
    end

    describe "and make a GET request with Net::HTTP.start" do
      before do
        http = Net::HTTP.new("google.com", 80)
        @response = http.get("/get")
      end

      it_should_behave_like "a working GET request"
      it_should_behave_like "a working HTTP request"
    end

    describe "and make a GET request with Net::HTTP.get_response" do
      before do
        @response = Net::HTTP.get_response(URI.parse("http://google.com/get"))
      end

      it_should_behave_like "a working GET request"
      it_should_behave_like "a working HTTP request"
    end

    describe "and make a GET request with Net::HTTP::Get.new" do
      before do
        Net::HTTP.start('google.com') do |http|
          req = Net::HTTP::Get.new('/get')
          @response = http.request(req)
        end
      end

      it_should_behave_like "a working GET request"
      it_should_behave_like "a working HTTP request"
    end
    
    describe "and make a POST request with Net::HTTP::Post.new" do
      before do
        Net::HTTP.start('google.com') do |http|
          req = Net::HTTP::Post.new('/index')
          req.body = 'foo=bar'
          @response = http.request(req)
        end
      end

      it_should_behave_like "a working POST request"
      it_should_behave_like "a working HTTP request"
    end
  end

  describe "when activating with a block" do
    
    before do
      ::Net::HTTP.should == NET_HTTP
    end

    after do
      ::Net::HTTP.should == NET_HTTP
    end

    it "deactivates automatically after the block is executed" do
      Artifice.activate_with( lambda {} ) do
        ::Net::HTTP.should == Artifice::Net::HTTP
      end
    end

    it "deactivates even if an exception is raised from within the block" do
      lambda {
        Artifice.activate_with( lambda {} ) do
          ::Net::HTTP.should == Artifice::Net::HTTP
          raise 'Boom!'
        end
      }.should raise_error
    end
  end

  describe Artifice, "#reactivate" do
    
    before do
      @endpoint = lambda {|env| [ 200, {}, [] ] }

      Artifice.activate_with @endpoint
      Artifice::Net::HTTP.endpoint.should == @endpoint
      ::Net::HTTP.should == Artifice::Net::HTTP

      Artifice.deactivate
      ::Net::HTTP.should == NET_HTTP
    end

    it "reactivates Artifice with the last endpoint that was used" do
      Artifice.reactivate
      Artifice::Net::HTTP.endpoint.should == @endpoint
      ::Net::HTTP.should == Artifice::Net::HTTP
    end

    it "can reactivate within a block" do
      Artifice.reactivate do
        Artifice::Net::HTTP.endpoint.should == @endpoint
        ::Net::HTTP.should == Artifice::Net::HTTP
      end
      ::Net::HTTP.should == NET_HTTP
    end
  end
end
