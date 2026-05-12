class DeleteAssetFileFromNfsJob
  include Sidekiq::Job
  sidekiq_options queue: "low_priority"

  def perform(asset_id); end
end
