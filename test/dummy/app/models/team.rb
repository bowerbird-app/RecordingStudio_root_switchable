class Team < ApplicationRecord
  include RecordingStudioAccessible::AllowsAccessibleChildren

  recording_studio_recordable label: "Team", root: true
  recording_studio_accessible_children :access

  validates :name, presence: true
end