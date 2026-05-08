FactoryBot.define do
  factory :asset do
    file { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/asset.png")) }
  end
  factory :clean_asset, parent: :asset do
    after :create, &:scanned_clean!
  end
  factory :infected_asset, parent: :asset do
    after :create, &:scanned_infected!
  end
  factory :uploaded_asset, parent: :clean_asset do
    after :create, &:upload_success!
  end

  factory :deleted_asset, parent: :asset do
    deleted_at { Time.zone.now }
  end
end
