# require "services"

class VirusScanJob
  include Sidekiq::Job

  sidekiq_options lock: :until_and_while_executing

  def perform(asset_id); end
end
