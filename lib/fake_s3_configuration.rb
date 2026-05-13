require "publishing_platform_configuration"

class FakeS3Configuration
  def initialize(env = ENV, publishing_platform_config = PublishingPlatformConfiguration.new)
    @env = env
    @publishing_platform_config = publishing_platform_config
  end

  def root
    Rails.root.join("fake-s3")
  end

  def path_prefix
    "/fake-s3"
  end

  def host
    @env["FAKE_S3_HOST"] || @publishing_platform_config.app_host || "http://localhost:3000"
  end
end
