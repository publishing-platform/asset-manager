require "rails_helper"

RSpec.describe "/media", type: :request do
  let(:s3) { S3Configuration.build }

  around do |example|
    # by default user is not authenticated
    ClimateControl.modify(PUBLISHING_PLATFORM_ASSET_ROOT: "http://assets.dev.publishing-platform.co.uk",
                          PUBLISHING_PLATFORM_SSO_MOCK_INVALID: "1") { example.run }
  end

  before do
    allow(AssetManager).to receive(:s3).and_return(s3)
    allow(s3).to receive(:fake?).and_return(false)
  end

  context "when requesting an asset that doesn't exist" do
    it "responds with not found status" do
      get download_media_path(id: 34, filename: "test.jpg")
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when requesting a previously uploaded asset which no longer exists" do
    let(:asset) { create(:deleted_asset) }

    it "responds with 410 Gone status" do
      get download_media_path(id: asset.id, filename: asset.filename)
      expect(response).to have_http_status(:gone)
    end
  end

  context "when requesting an asset that does exist" do
    let(:asset) { create(:uploaded_asset) }
    let(:cloud_storage) { instance_double(S3Storage) }
    let(:http_method) { "GET" }
    let(:presigned_url) { "https://s3-host.test/presigned-url" }
    let(:last_modified) { Time.zone.parse("2017-01-01 00:00") }

    before do
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      allow(cloud_storage).to receive(:presigned_url_for)
        .with(asset, http_method:).and_return(presigned_url)
      allow(Asset).to receive(:find).with(asset.id.to_s).and_return(asset)
      allow(asset).to receive_messages(etag: "599ffda8-e169", last_modified:)
    end

    shared_examples "a download response" do
      it "instructs Nginx to proxy the request to S3" do
        expect(response.headers["X-Accel-Redirect"]).to match("/cloud-storage-proxy/#{presigned_url}")
      end

      it "returns an ok response" do
        expect(response).to have_http_status(:ok)
      end
    end

    shared_examples "a not modified response" do
      it "does not instruct Nginx to proxy the request to S3" do
        expect(response.headers).not_to include("X-Accel-Redirect")
      end

      it "returns a not modified response" do
        expect(response).to have_http_status(:not_modified)
      end
    end

    it "sets the X-Frame-Options header to DENY" do
      get download_media_path(id: asset, filename: asset.filename)
      expect(response.headers["X-Frame-Options"]).to eq("DENY")
    end

    it "sends ETag response header with quoted value" do
      get download_media_path(id: asset, filename: asset.filename)

      expect(response.headers["ETag"]).to eq(%("599ffda8-e169"))
    end

    it "sends Last-Modified response header in HTTP time format" do
      get download_media_path(id: asset, filename: asset.filename)

      expect(response.headers["Last-Modified"]).to eq("Sun, 01 Jan 2017 00:00:00 GMT")
    end

    it "sends Content-Disposition response header based on asset filename" do
      get download_media_path(id: asset, filename: asset.filename)

      expect(response.headers["Content-Disposition"]).to eq("inline; filename=\"#{asset.filename}\"")
    end

    it "sends an Asset's content_type when one is set" do
      allow(asset).to receive(:content_type).and_return("image/jpeg")
      get download_media_path(id: asset, filename: asset.filename)

      expect(response.headers["Content-Type"]).to eq("image/jpeg")
    end

    it "determines an Asset's content_type by filename when it is not set" do
      allow(asset).to receive_messages(content_type: nil, filename: "file.pdf")
      get download_media_path(id: asset, filename: asset.filename)

      expect(response.headers["Content-Type"]).to eq("application/pdf")
    end

    it "sets Cache-Control header to expire in 30 minutes and be publicly cacheable" do
      get download_media_path(id: asset, filename: asset.filename)

      expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
    end

    context "when there aren't conditional headers" do
      before { get download_media_path(id: asset, filename: asset.filename) }

      it_behaves_like "a download response"
    end

    context "when a conditional request is made using an ETag that matches the asset ETag" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: { "If-None-Match" => %("#{asset.etag}") }
      end

      it_behaves_like "a not modified response"
    end

    context "when a conditional request is made using an ETag that does not match the asset ETag" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: { "If-None-Match" => %("made-up-etag") }
      end

      it_behaves_like "a download response"
    end

    context "when a conditional request is made using a timestamp that matches the asset timestamp" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: { "If-Modified-Since" => asset.last_modified.httpdate }
      end

      it_behaves_like "a not modified response"
    end

    context "when a conditional request is made using a timestamp that is earlier than the asset timestamp" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: { "If-Modified-Since" => (asset.last_modified - 1.day).httpdate }
      end

      it_behaves_like "a download response"
    end

    context "when a conditional request is made using a timestamp that is later than the asset timestamp" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: { "If-Modified-Since" => (asset.last_modified + 1.day).httpdate }
      end

      it_behaves_like "a not modified response"
    end

    context "when a conditional request is made using an Etag and timestamp that match the asset" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: {
              "If-None-Match" => %("#{asset.etag}"),
              "If-Modified-Since" => (asset.last_modified + 1.day).httpdate,
            }
      end

      it_behaves_like "a not modified response"
    end

    # when both headers are present only the ETag is considered
    # as specified by RFC 7232 section 6.
    context "when a conditional request is made using an Etag that matches and timestamp that does not match the asset" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: {
              "If-None-Match" => %("#{asset.etag}"),
              "If-Modified-Since" => (asset.last_modified - 1.day).httpdate,
            }
      end

      it_behaves_like "a not modified response"
    end

    context "when a conditional request is made using an Etag that does not match and a timestamp that matches the asset" do
      before do
        get download_media_path(id: asset, filename: asset.filename),
            headers: {
              "If-None-Match" => "made-up-etag",
              "If-Modified-Since" => asset.last_modified.httpdate,
            }
      end

      it_behaves_like "a download response"
    end

    context "when the file name in the URL represents an old version" do
      let(:old_file_name) { "an_old_filename.pdf" }

      before do
        allow(asset).to receive(:filename_valid?).and_return(true)
      end

      it "redirects to the new file name" do
        get download_media_path(id: asset, filename: old_file_name)

        expect(response.location).to match(download_media_path(id: asset, filename: "asset.png"))
      end
    end

    context "when the file name in the URL is invalid" do
      let(:invalid_file_name) { "invalid_file_name.pdf" }

      it "responds with 404 Not Found" do
        get download_media_path(id: asset, filename: invalid_file_name)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with draft uploaded asset" do
      let(:asset) { create(:uploaded_asset, draft: true) }
      let(:draft_assets_host) { AssetManager.publishing_platform.draft_assets_host }
      let(:internal_host) { URI.parse(PublishingPlatformLocation.find("asset-manager")).host }

      context "when requested from host other than draft-assets or internal host" do
        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => "not-draft-assets-or-internal-host",
              }
        end

        it "redirects to draft assets host" do
          expected_url = "http://#{draft_assets_host}#{asset.public_url_path}"
          expect(response).to redirect_to expected_url
        end
      end

      context "when requested from draft-assets host and not authenticated" do
        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
              }
        end

        it "requires authentication" do
          expect(response).to redirect_to("/auth/publishing_platform")
        end
      end

      context "when requested from internal host and not authenticated" do
        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => internal_host,
              }
        end

        it "requires authentication" do
          expect(response).to redirect_to("/auth/publishing_platform")
        end
      end

      context "when requested from draft-assets host and authenticated" do
        around do |example|
          ClimateControl.modify(PUBLISHING_PLATFORM_SSO_MOCK_INVALID: nil) { example.run }
        end

        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
              }
        end

        it_behaves_like "a download response"

        it "sets Cache-Control header to no-cache" do
          expect(response.headers["Cache-Control"]).to eq("no-cache")
        end
      end

      context "when requested from internal host and authenticated" do
        around do |example|
          ClimateControl.modify(PUBLISHING_PLATFORM_SSO_MOCK_INVALID: nil) { example.run }
        end

        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => internal_host,
              }
        end

        it_behaves_like "a download response"

        it "sets Cache-Control header to no-cache" do
          expect(response.headers["Cache-Control"]).to eq("no-cache")
        end
      end

      context "when the file name in the URL is invalid and the user is not authenticated" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        before do
          get download_media_path(id: asset, filename: invalid_file_name),
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
              }
        end

        it "requires authentication" do
          expect(response).to redirect_to("/auth/publishing_platform")
        end
      end

      context "when the file name in the URL is invalid and the user is authenticated" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        around do |example|
          ClimateControl.modify(PUBLISHING_PLATFORM_SSO_MOCK_INVALID: nil) { example.run }
        end

        before do
          get download_media_path(id: asset, filename: invalid_file_name),
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
              }
        end

        it "responds with 404 Not Found" do
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "with draft uploaded asset with auth_bypass_ids" do
      let(:auth_bypass_id) { "bypass-id" }
      let(:asset) { create(:uploaded_asset, draft: true, auth_bypass_ids: [auth_bypass_id]) }
      let(:draft_assets_host) { AssetManager.publishing_platform.draft_assets_host }
      let(:valid_token) do
        JWT.encode(
          { "sub" => auth_bypass_id },
          Rails.application.credentials.jwt_auth_secret,
          "HS256",
        )
      end

      context "when a user is not authenticated and has provided a valid token by query string" do
        before do
          get download_media_path(id: asset, filename: asset.filename),
              params: {
                token: valid_token,
              },
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
              }
        end
        it "grants access to the file" do
          expect(response).to have_http_status(:ok)
        end
      end

      context "when a user is not authenticated and has provided a valid token by cookie" do
        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
                cookie: "auth_bypass_token=#{valid_token}",
              }
        end

        it "grants access to the file" do
          expect(response).to have_http_status(:ok)
        end
      end

      context "when a user is not authenticated and has provided an invalid token" do
        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
                cookie: "auth_bypass_token=bad_token",
              }
        end

        it "requires authentication" do
          expect(response).to redirect_to("/auth/publishing_platform")
        end
      end

      context "when user is authenticated" do
        around do |example|
          ClimateControl.modify(PUBLISHING_PLATFORM_SSO_MOCK_INVALID: nil) { example.run }
        end

        before do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => draft_assets_host,
              }
        end

        it "grants access to the file" do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "with an unscanned file" do
      let(:asset) { create(:asset) }

      it "responds with 404 Not Found" do
        get download_media_path(id: asset, filename: asset.filename)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a valid clean file" do
      let(:asset) { create(:clean_asset) }

      it "responds with 404 Not Found" do
        get download_media_path(id: asset, filename: asset.filename)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an infected file" do
      let(:asset) { create(:infected_asset) }

      it "responds with 404 Not Found" do
        get download_media_path(id: asset, filename: asset.filename)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when asset has a redirect URL" do
      let(:redirect_url) { "https://example.com/path/file.ext" }
      let(:asset) { create(:uploaded_asset, redirect_url:) }

      it "redirects to redirect URL" do
        get download_media_path(id: asset, filename: asset.filename)

        expect(response).to redirect_to(redirect_url)
      end
    end

    context "when asset has a replacement" do
      let(:replaced_by) { create(:uploaded_asset) }
      let(:asset) { create(:uploaded_asset, replaced_by:) }

      it "redirects to replacement for asset" do
        get download_media_path(id: asset, filename: asset.filename)

        expected_url = "//#{AssetManager.publishing_platform.assets_host}#{replaced_by.public_url_path}"
        expect(response).to redirect_to(expected_url)
      end

      it "responds with 301 moved permanently status" do
        get download_media_path(id: asset, filename: asset.filename)

        expect(response).to have_http_status(:moved_permanently)
      end

      it "sets the Cache-Control response header to 30 minutes" do
        get download_media_path(id: asset, filename: asset.filename)

        expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
      end

      context "and the asset is draft and is requested from not the draft host" do
        before do
          asset.draft = true
          asset.save!(validate: false)

          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => "not-#{AssetManager.publishing_platform.draft_assets_host}",
              }
        end

        it "redirects if the replacement is live" do
          expected_url = "//#{AssetManager.publishing_platform.assets_host}#{replaced_by.public_url_path}"
          expect(response).to redirect_to(expected_url)
        end
      end

      context "and the replacement is draft" do
        before do
          replaced_by.update(draft: true)
        end

        it "serves the original asset when requested via something other than the draft-assets host" do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => "not-#{AssetManager.publishing_platform.draft_assets_host}",
              }

          expect(response.headers["X-Accel-Redirect"]).to match("/cloud-storage-proxy/#{presigned_url}")
          expect(response).to have_http_status(:ok)
        end

        it "redirects to the replacement asset when requested via the draft-assets host" do
          get download_media_path(id: asset, filename: asset.filename),
              headers: {
                "X-Forwarded-Host" => AssetManager.publishing_platform.draft_assets_host,
              }

          expected_url = "//#{AssetManager.publishing_platform.draft_assets_host}#{replaced_by.public_url_path}"
          expect(response).to redirect_to expected_url
        end
      end
    end

    context "when the asset doesn't contain a parent_document_url" do
      let(:asset) { create(:uploaded_asset) }

      before do
        asset.update(parent_document_url: nil)
      end

      it "doesn't send a Link HTTP header" do
        get download_media_path(id: asset, filename: asset.filename)

        expect(response.headers["Link"]).to be_nil
      end
    end

    context "when the asset has a parent_document_url" do
      let(:asset) { create(:uploaded_asset) }

      before do
        asset.parent_document_url = "parent-document-url"
        asset.save!(validate: false)
      end

      it "sends the parent_document_url in a Link HTTP header" do
        get download_media_path(id: asset, filename: asset.filename)

        expect(response.headers["Link"]).to eql('<parent-document-url>; rel="up"')
      end
    end
  end
end
