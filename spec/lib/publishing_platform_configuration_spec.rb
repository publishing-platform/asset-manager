require "rails_helper"
require "publishing_platform_configuration"

RSpec.describe PublishingPlatformConfiguration do
  subject(:config) { described_class.new(env) }

  describe "#app_host" do
    context "when environment includes PUBLISHING_PLATFORM_APP_NAME & PUBLISHING_PLATFORM_APP_DOMAIN" do
      let(:env) do
        {
          "PUBLISHING_PLATFORM_APP_NAME" => "asset-manager",
          "PUBLISHING_PLATFORM_APP_DOMAIN" => "dev.publishing-platform.co.uk",
        }
      end

      it "returns application host including protocol" do
        expect(config.app_host).to eq("http://asset-manager.dev.publishing-platform.co.uk")
      end
    end

    context "when environment only includes PUBLISHING_PLATFORM_APP_NAME" do
      let(:env) do
        {
          "PUBLISHING_PLATFORM_APP_NAME" => "asset-manager",
        }
      end

      it "returns nil" do
        expect(config.app_host).to be_nil
      end
    end

    context "when environment only includes PUBLISHING_PLATFORM_APP_DOMAIN" do
      let(:env) do
        {
          "PUBLISHING_PLATFORM_APP_DOMAIN" => "dev.publishing-platform.co.uk",
        }
      end

      it "returns nil" do
        expect(config.app_host).to be_nil
      end
    end

    context "when environment does not include PUBLISHING_PLATFORM_APP_NAME or PUBLISHING_PLATFORM_APP_DOMAIN" do
      let(:env) { {} }

      it "returns nil" do
        expect(config.app_host).to be_nil
      end
    end
  end

  describe "#clamscan_path" do
    context "when environment includes an ASSET_MANAGER_CLAMSCAN_PATH value" do
      let(:env) do
        {
          "ASSET_MANAGER_CLAMSCAN_PATH" => "alternative-path",
        }
      end

      it "returns environment variable" do
        expect(config.clamscan_path).to eq("alternative-path")
      end
    end

    context "when environment does not include an ASSET_MANAGER_CLAMSCAN_PATH value" do
      let(:env) { {} }

      it "returns default value" do
        expect(config.clamscan_path).to eq("clamdscan")
      end
    end
  end

  describe "#draft_assets_host" do
    subject(:config) { described_class.new(env) }

    let(:env) { {} }

    before do
      allow(PublishingPlatformLocation).to receive(:external_url_for).with("draft-assets")
        .and_return("https://draft-assets.publishing.service.publishing-platform.co.uk")
    end

    it "returns externally facing draft-assets host" do
      expect(config.draft_assets_host).to eq("draft-assets.publishing.service.publishing-platform.co.uk")
    end
  end
end
