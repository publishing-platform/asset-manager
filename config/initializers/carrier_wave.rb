directory = if Rails.env.test?
              Rails.root.join("tmp/test_uploads")
            elsif ENV["PUBLISHING_PLATFORM_UPLOADS_ROOT"]
              ENV["PUBLISHING_PLATFORM_UPLOADS_ROOT"]
            else
              Rails.root.join("uploads")
            end

AssetManager.carrier_wave_store_base_dir = directory
