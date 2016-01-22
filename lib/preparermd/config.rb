require 'json'

module PreparerMD

  # Configuration values and credentials read from the process' environment.
  #
  class Config
    attr_reader :content_root
    attr_reader :content_store_url, :content_store_apikey, :content_store_tls_verify
    attr_reader :content_id_base, :jekyll_document, :github_url, :github_branch, :meta


    # Create a new configuration populated with values from the environment.
    #
    def initialize
      @content_root = ENV.fetch('CONTENT_ROOT', '')

      @content_store_url = ENV.fetch('CONTENT_STORE_URL', '').gsub(%r{/\Z}, '')
      @content_store_apikey = ENV.fetch('CONTENT_STORE_APIKEY', '')
      @content_store_tls_verify = ENV.fetch('CONTENT_STORE_TLS_VERIFY', '') != 'false'

      @content_id_base = ENV.fetch('CONTENT_ID_BASE', '').gsub(%r{/\Z}, '')
      @jekyll_document = ENV.fetch('JEKYLL_DOCUMENT', '')
    end

    def has_content_root?
      ! @content_root.empty?
    end

    def load_from(f)
      jsondata = JSON.parse(f)

      if jsondata["contentIDBase"]
        if @content_id_base == ""
          @content_id_base = jsondata["contentIDBase"].gsub(%r{/\Z}, '')
        elsif @content_id_base != jsondata["contentIDBase"].gsub(%r{/\Z}, '')
          $stderr.puts "Using environment variable CONTENT_ID_BASE=[#{@content_id_base}] " \
            "instead of _deconst.json setting [#{jsondata["contentIDBase"]}]."
        end
      end

      if jsondata["meta"]
        @meta = jsondata["meta"]
      else
        @meta = {}
      end

      if jsondata["githubUrl"]
        @github_url = jsondata["githubUrl"]

        @meta["github_issues_url"] = [@github_url, '/issues'].map { |s|
          s.gsub(/\/$/, '').gsub(/^\//, '')
        }.join('/')
      end

      if jsondata["githubBranch"]
        @github_branch = jsondata["githubBranch"]
      else
        @github_branch = "master"
      end
    end

    # Determine and report (to stderr) whether or not we have enough information to submit to the
    # content service.
    #
    def validate
      reasons = []

      if @content_store_url.empty?
        reasons << "CONTENT_STORE_URL is missing. It should be the base URL of the content " \
          "storage service."
      end

      if @content_store_apikey.empty?
        reasons << "CONTENT_STORE_APIKEY is missing. It should be a valid API key issued by the " \
          "content service."
      end

      if @content_id_base.empty?
        reasons << "CONTENT_ID_BASE is missing. It should be the common prefix used to generate " \
          "IDs for content within this repository."
      end

      if ENV['TRAVIS_PULL_REQUEST'] != "false"
        reasons << "This looks like a pull request build on Travis."
      end

      unless @content_store_tls_verify
        $stderr.puts
        $stderr.puts "TLS certificate verification disabled!"
        $stderr.puts
      end

      if reasons.empty?
        puts "Content will be submitted to the content service."

        @should_submit = true
      else
        $stderr.puts "Not submitting content to the content service because:"
        $stderr.puts
        $stderr.puts reasons.map { |r| " * #{r}\n"}.join
        $stderr.puts

        @should_submit = false
      end
    end

    # Determine whether or not we have enough information to submit to the content service.
    #
    def should_submit?
      raise "#validate must be called first!" if @should_submit.nil?

      @should_submit
    end
  end

end
