class Asset < ApplicationRecord
  # based on https://tools.ietf.org/html/rfc6838#section-4.2
  CONTENT_TYPE_FORMAT = %r{
    \A
    \w[\w!#&\-^_.+]+ # type
    / # separating slash
    \w[\w!#&\-^_.+]+ # subtype
    \Z
  }x

  belongs_to :replaced_by,
             class_name: "Asset",
             optional: true

  attribute :uuid, default: -> { SecureRandom.uuid }
  attr_readonly :uuid

  validates :file, presence: true, if: :unscanned?

  validates :uuid,
            presence: true,
            uniqueness: true,
            format: {
              with: /[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/,
              message: "must match the format defined in rfc4122",
            }

  validates :content_type,
            format: {
              with: CONTENT_TYPE_FORMAT,
              message: "must match the format defined in rfc6838",
              allow_nil: true,
            }

  validate :check_specified_replacement_exists
  validate :prevent_transition_from_published_to_draft_if_replaced
  validate :ensure_parent_document_url_is_valid

  mount_uploader :file, AssetUploader

  before_save :store_metadata, unless: :uploaded?
  after_save :schedule_virus_scan
  after_save :update_indirect_replacements_on_publish
  after_save :backpropagate_replacement

  scope :deleted, -> { where.not(deleted_at: nil) }
  scope :undeleted, -> { where(deleted_at: nil) }

  state_machine :state, initial: :unscanned do
    around_transition do |asset, transition, block|
      Rails.logger.info("#{asset.id} - Asset#state_machine - event: #{transition.event}")
      block.call
    end

    event :scanned_clean do
      transition unscanned: :clean
    end

    after_transition to: :clean do |asset, _|
      SaveToCloudStorageJob.perform_async(asset.id)
    end

    event :scanned_infected do
      transition unscanned: :infected
    end

    event :upload_success do
      transition clean: :uploaded
    end

    after_transition to: :uploaded do |asset, _|
      asset.save!
      DeleteAssetFileFromNfsJob.perform_in(5.minutes, asset.id)
    end
  end

  def valid_auth_bypass_token?(auth_bypass_id)
    auth_bypass_ids.include?(auth_bypass_id)
  end

  def public_url_path
    "/media/#{id}/#{filename}"
  end

  def file=(file)
    old_filename = filename
    super(file).tap do
      filename_history.push(old_filename) if old_filename
    end
    reset_state
  end

  def filename_valid?(filename_to_test)
    valid_filenames.include?(filename_to_test)
  end

  def filename
    file.file.try(:identifier)
  end

  def extension
    File.extname(filename).downcase.delete(".")
  end

  def content_type_from_extension
    mime_type = Mime::Type.lookup_by_extension(extension)
    mime_type ? mime_type.to_s : AssetManager.default_content_type
  end

  def image?
    %w[jpg jpeg png gif].include?(extension)
  end

  def etag_from_file
    sprintf("%<mtime>x-%<size>x", mtime: last_modified_from_file, size: file_stat.size) if file_exists?
  end

  def last_modified_from_file
    file_stat.mtime if file_exists?
  end

  def md5_hexdigest_from_file
    @md5_hexdigest_from_file ||= Digest::MD5.hexdigest(file.file.read) if file_exists?
  end

  def size_from_file
    file_stat.size if file_exists?
  end

  def update_indirect_replacements_on_publish
    return unless saved_change_to_attribute(:draft) && !draft?

    Asset.where(replaced_by_id: id).find_each do |replaced_by_me|
      Asset.where(replaced_by_id: replaced_by_me.id).find_each do |indirectly_replaced_by_me|
        indirectly_replaced_by_me.update(replaced_by: self)
      end
    end
  end

  def backpropagate_replacement
    return if replaced_by.blank? || replaced_by.draft?

    Asset.where(replaced_by_id: id).find_each do |replaced_by_me|
      replaced_by_me.update(replaced_by:)
    end
  end

  def destroy
    update!(deleted_at: Time.zone.now)
  end

  def restore
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

private

  def store_metadata
    self.etag = etag_from_file
    self.last_modified = last_modified_from_file
    self.md5_hexdigest = md5_hexdigest_from_file
    self.size = size_from_file
  end

  def valid_filenames
    filename_history + [filename]
  end

  def reset_state
    self.state = "unscanned"
    @md5_hexdigest_from_file = nil
  end

  def schedule_virus_scan
    VirusScanJob.perform_async(id) if unscanned? && redirect_url.blank?
  end

  def file_exists?
    File.exist?(file.path)
  end

  def file_stat
    File.stat(file.path)
  end

  def check_specified_replacement_exists
    replacement = Asset.where(id: replaced_by_id)
    if replaced_by_id.present? && replacement.blank?
      errors.add(:replaced_by, "not found")
    end
  end

  def prevent_transition_from_published_to_draft_if_replaced
    if changes[:draft] == [false, true]
      if replaced_by.present?
        errors.add(:draft, "cannot be true, because already replaced")
      end
      if redirect_url.present?
        errors.add(:draft, "cannot be true, because already redirected")
      end
    end
  end

  def ensure_parent_document_url_is_valid
    return if parent_document_url.blank?

    begin
      uri = Addressable::URI.parse(parent_document_url)
    rescue Addressable::URI::InvalidURIError
      uri = nil
    end

    unless uri && %w[http https].include?(uri.scheme)
      errors.add(:parent_document_url, "must be an http(s) URL")
    end

    if uri && uri.host.start_with?("draft-origin") && !draft?
      errors.add(:parent_document_url, "must be a public publishing-platform.co.uk URL")
    end
  end
end
