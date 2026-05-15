require "rails_helper"

RSpec.describe "/assets", type: :request do
  around do |example|
    ClimateControl.modify(PUBLISHING_PLATFORM_ASSET_ROOT: "http://assets.dev.publishing-platform.co.uk") { example.run }
  end

  describe "GET /show" do
    it "returns details about an existing asset" do
      asset = create(:uploaded_asset)

      get asset_path(asset.id)

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)

      expect(body["_response_info"]["status"]).to eq("ok")

      expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["file_url"]).to eq("http://assets.dev.publishing-platform.co.uk/media/#{asset.id}/asset.png")
      expect(body["state"]).to eq("uploaded")
      expect(body["draft"]).to be false
      expect(body["deleted"]).to be false
    end

    it "returns details about an infected asset" do
      asset = create(:infected_asset)

      get asset_path(asset.id)
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(body["_response_info"]["status"]).to eq("ok")

      expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["file_url"]).to eq("http://assets.dev.publishing-platform.co.uk/media/#{asset.id}/asset.png")
      expect(body["state"]).to eq("infected")
      expect(body["draft"]).to be false
      expect(body["deleted"]).to be false
    end

    it "sets the Cache-Control header to no-cache" do
      asset = create(:uploaded_asset)

      get asset_path(asset.id)

      expect(response.headers["Cache-Control"]).to eq("no-cache")
    end

    it "returns details about a deleted asset" do
      asset = create(:deleted_asset)

      get asset_path(asset.id)
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(body["_response_info"]["status"]).to eq("ok")

      expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["file_url"]).to eq("http://assets.dev.publishing-platform.co.uk/media/#{asset.id}/asset.png")
      expect(body["state"]).to eq("unscanned")
      expect(body["draft"]).to be false
      expect(body["deleted"]).to be true
    end

    it "cannot retrieve details about an asset which does not exist" do
      get "/assets/blah"
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:not_found)
      expect(body["_response_info"]["status"]).to eq("not found")
    end
  end

  describe "POST /create" do
    let(:file) { load_fixture_file("asset.png") }
    let(:valid_attributes) { { file: } }

    context "when attributes are valid" do
      it "responds with created status" do
        post assets_path, params: { asset: valid_attributes }
        expect(response).to have_http_status(:created)
      end
      it "responds with the details of the new asset" do
        post assets_path, params: { asset: valid_attributes }
        body = JSON.parse(response.body)

        expect(body["_response_info"]["status"]).to eq("created")
        expect(body["id"]).to match(%r{http://www.example.com/assets/[0-9]+})
        expect(body["name"]).to eq("asset.png")
        expect(body["content_type"]).to eq("image/png")
        expect(body["file_url"]).to match(%r{http://assets.dev.publishing-platform.co.uk/media/[0-9]+/asset.png})
        expect(body["state"]).to eq("unscanned")
        expect(body["draft"]).to be false
        expect(body["deleted"]).to be false
      end

      it "stores auth_bypass_ids on asset" do
        post assets_path, params: { asset: valid_attributes.merge(auth_bypass_ids: %w[id1 id2]) }

        expect(Asset.last.auth_bypass_ids).to eq(%w[id1 id2])
      end

      it "stores parent_document_url on asset" do
        post assets_path, params: { asset: valid_attributes.merge(parent_document_url: "http://parent-document-url") }

        expect(Asset.last.parent_document_url).to eq("http://parent-document-url")
      end

      it "stores a specified content type" do
        post assets_path, params: { asset: valid_attributes.merge(content_type: "application/pdf") }

        expect(Asset.last.content_type).to eq("application/pdf")
      end

      context "when attributes include draft status" do
        let(:attributes) { valid_attributes.merge(draft: true) }

        it "stores draft status on asset" do
          post assets_path, params: { asset: attributes }

          expect(Asset.last).to be_draft
        end

        it "includes the draft status in the response" do
          post assets_path, params: { asset: attributes }

          body = JSON.parse(response.body)

          expect(body["draft"]).to be_truthy
        end
      end

      context "when attributes include a redirect URL" do
        let(:redirect_url) { "https://example.com/path/file.ext" }
        let(:attributes) { valid_attributes.merge(redirect_url:) }

        it "stores redirect URL on asset" do
          post assets_path, params: { asset: attributes }

          expect(Asset.last.redirect_url).to eq(redirect_url)
        end

        context "and redirect URL is blank" do
          let(:redirect_url) { "" }

          it "stores redirect URL as nil" do
            post assets_path, params: { asset: attributes }

            expect(Asset.last.redirect_url).to be_nil
          end
        end
      end

      context "when attributes include a replaced_by_id" do
        let(:replaced_by) { create(:asset) }
        let(:replaced_by_id) { replaced_by.id }
        let(:attributes) { valid_attributes.merge(replaced_by_id:) }

        it "stores replacement asset" do
          post assets_path, params: { asset: attributes }

          expect(Asset.last.replaced_by).to eq(replaced_by)
        end

        context "and replaced_by_id is blank" do
          let(:replaced_by_id) { "" }

          it "stores no replacement" do
            post assets_path, params: { asset: attributes }

            expect(Asset.last.replaced_by).to be_blank
          end

          it "stores replaced_by_id as nil" do
            post assets_path, params: { asset: attributes }

            expect(Asset.last.replaced_by_id).to be_nil
          end
        end

        context "and replaced_by_id does not match an existing asset" do
          let(:replaced_by_id) { "non-existent-asset-id" }

          it "responds with unprocessable entity status" do
            post assets_path, params: { asset: attributes }

            expect(response).to have_http_status(:unprocessable_content)
          end

          it "includes error message in response" do
            post assets_path, params: { asset: attributes }

            body = JSON.parse(response.body)
            status = body["_response_info"]["status"]
            expect(status).to include("Replaced by not found")
          end
        end

        it "includes the replaced_by_id in the response" do
          post assets_path, params: { asset: attributes }

          body = JSON.parse(response.body)

          expect(body["replaced_by_id"]).to eq(replaced_by_id)
        end
      end
    end

    context "when attributes are invalid" do
      let(:invalid_attributes) { { file: nil } }

      it "responds with unprocessable entity status" do
        post assets_path, params: { asset: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "responds with details of error" do
        post assets_path, params: { asset: invalid_attributes }
        body = JSON.parse(response.body)

        expect(body["_response_info"]["status"]).to eq(["File can't be blank"])
      end

      it "does not presist asset" do
        post assets_path, params: { asset: invalid_attributes }
        expect(Asset.count).to eq 0
      end
    end
  end

  describe "PUT /update" do
    context "with an existing asset" do
      let(:asset) { create(:asset) }
      let(:file) { load_fixture_file("asset2.jpg") }
      let(:valid_attributes) { { file: } }

      it "responds with success status" do
        put asset_path(asset.id), params: { asset: valid_attributes }

        expect(response).to have_http_status(:success)
      end

      it "responds with the details of the existing asset" do
        put asset_path(asset.id), params: { asset: valid_attributes }

        body = JSON.parse(response.body)

        expect(body["_response_info"]["status"]).to eq("success")

        expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
        expect(body["name"]).to eq("asset2.jpg")
        expect(body["content_type"]).to eq("image/jpeg")
        expect(body["file_url"]).to eq("http://assets.dev.publishing-platform.co.uk/media/#{asset.id}/asset2.jpg")
        expect(body["state"]).to eq("unscanned")
        expect(body["draft"]).to be false
        expect(body["deleted"]).to be false
      end

      it "stores file on existing asset" do
        put asset_path(asset.id), params: { asset: valid_attributes }

        expect(Asset.first.file.path).to match(/asset2\.jpg$/)
      end

      it "stores auth_bypass_ids on existing asset" do
        attributes = valid_attributes.merge(auth_bypass_ids: %w[bypass-id])
        put asset_path(asset.id), params: { asset: attributes }

        expect(Asset.first.auth_bypass_ids).to eq(%w[bypass-id])
      end

      it "copes when auth_bypass_ids are passed in as an empty string" do
        asset.update!(auth_bypass_ids: %w[bypass-1 bypass-2])

        # We have to use an empty string as that is what gds-api-adapters/rest-client
        # will generate instead of an empty array
        attributes = valid_attributes.merge(auth_bypass_ids: "")
        put asset_path(asset.id), params: { asset: attributes }

        expect(Asset.first.auth_bypass_ids).to eq([])
      end

      it "stores redirect_url on existing asset" do
        redirect_url = "https://example.com/path/file.ext"
        attributes = valid_attributes.merge(redirect_url:)
        put asset_path(asset.id), params: { asset: attributes }

        expect(Asset.first.redirect_url).to eq(redirect_url)
      end

      it "stores blank redirect_url as nil on existing asset" do
        redirect_url = ""
        attributes = valid_attributes.merge(redirect_url:)
        put asset_path(asset.id), params: { asset: attributes }

        expect(Asset.first.redirect_url).to be_nil
      end

      it "removes existing redirect_url from existing asset if empty one is sent" do
        redirect_url = "https://example.com/path/file.ext"
        attributes = valid_attributes.merge(redirect_url:)
        put asset_path(asset.id), params: { asset: attributes }
        expect(Asset.first.redirect_url).to eq(redirect_url)

        attributes = valid_attributes.merge(redirect_url: "")
        put asset_path(asset.id), params: { asset: attributes }
        expect(Asset.first.redirect_url).to be_nil
      end
    end
  end
end
