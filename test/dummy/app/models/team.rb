class Team < ApplicationRecord
  recording_studio_recordable label: "Team", root: true
  RecordingStudio.enable_capability(:accessible, on: self)

  validates :name, presence: true
end
