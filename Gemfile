require 'openssl'
source 'https://rubygems.org'
gemspec

if ENV['RAILS_SOURCE']
  gemspec path: ENV['RAILS_SOURCE']
else
  def get_version_from_gemspec
    require 'net/http'
    require 'yaml'
    spec = eval(File.read('activerecord-cockroachdb-adapter.gemspec'))
    ver = spec.dependencies.detect{ |d|d.name == 'activerecord' }.requirement.requirements.first.last.version
    major, minor, tiny, pre = ver.split('.')

    if !pre
      uri = URI.parse "https://rubygems.org/api/v1/versions/activerecord.yaml"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      YAML.load(http.request(Net::HTTP::Get.new(uri.request_uri)).body).select do |data|
        a, b, c = data['number'].split('.')
        !data['prerelease'] && major == a && (minor.nil? || minor == b)
      end.first['number']
    else
      ver
    end
  end

  # Get Rails from source beacause the gem doesn't include tests
  version = ENV['RAILS_VERSION'] || get_version_from_gemspec
  gem 'rails', git: "https://github.com/rails/rails.git", tag: "v#{version}"
end
