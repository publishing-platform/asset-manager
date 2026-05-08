FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "Winston #{n}" }
    permissions { %w[signin] }
  end
end
