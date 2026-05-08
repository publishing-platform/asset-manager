# require "services"

class SaveToCloudStorageJob
  include Sidekiq::Job

  def perform(asset_id); end
end
