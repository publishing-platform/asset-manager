class User < ApplicationRecord
  include PublishingPlatform::SSO::User

  serialize :permissions, type: Array, coder: YAML
end
