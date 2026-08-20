# frozen_string_literal: true

class MessageRoot < ApplicationRecord
  recording_studio_recordable label: "Messages", root: true, shared: true

  validates :name, presence: true
end
