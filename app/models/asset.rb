class Asset < ApplicationRecord
  belongs_to :replaced_by,
             class_name: "Asset",
             optional: true
end
