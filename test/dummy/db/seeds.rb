# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

admin_attributes = DemoUsers.fetch(:admin)
viewer_attributes = DemoUsers.fetch(:viewer)

admin = User.find_or_create_by!(email: admin_attributes.fetch(:email)) do |u|
  u.password = admin_attributes.fetch(:password)
  u.password_confirmation = admin_attributes.fetch(:password)
end

viewer = User.find_or_create_by!(email: viewer_attributes.fetch(:email)) do |u|
  u.password = viewer_attributes.fetch(:password)
  u.password_confirmation = viewer_attributes.fetch(:password)
end

workspace_names = [
  "Studio Workspace",
  "Client Alpha",
  "Client Beta",
  "Hidden Workspace"
]

pages_by_workspace = {
  "Studio Workspace" => [
    {
      title: "Studio Handbook",
      body: "Shared studio operating notes, intake steps, and room readiness checks."
    },
    {
      title: "Session Calendar",
      body: "This root highlights upcoming recording blocks and producer handoffs."
    },
    {
      title: "Mix Notes",
      body: "Centralized revision notes for active internal sessions."
    }
  ],
  "Client Alpha" => [
    {
      title: "Alpha Launch Brief",
      body: "Messaging priorities and approval contacts for Client Alpha deliverables."
    },
    {
      title: "Alpha Asset Checklist",
      body: "Open items for stems, artwork, and release metadata in the Alpha workspace."
    }
  ],
  "Client Beta" => [
    {
      title: "Beta Campaign Outline",
      body: "Narrative beats and timing cues tailored to Client Beta's campaign."
    },
    {
      title: "Beta Review Queue",
      body: "Pending review links and sign-off notes for the Beta team."
    },
    {
      title: "Beta Delivery Log",
      body: "Delivered mixes and timestamped follow-up requests for Beta stakeholders."
    }
  ],
  "Hidden Workspace" => [
    {
      title: "Internal Archive",
      body: "An inaccessible root used to prove hidden workspaces stay out of scope."
    }
  ]
}

root_recordings = workspace_names.index_with do |name|
  workspace = Workspace.find_or_create_by!(name: name)
  RecordingStudio.root_recording_for(workspace)
end

team = Team.find_or_create_by!(name: "Operations Team")
team_root_recording = RecordingStudio.root_recording_for(team)

message_root = MessageRoot.find_or_create_by!(name: "Studio Messages")
RecordingStudio.root_recording_for(message_root)

ensure_owner_access = lambda do |recording:|
  result = RecordingStudioAccessible.bootstrap_owner_access!(
    recording: recording,
    actor: admin
  )
  raise result.error if result.failure?
end

ensure_granted_access = lambda do |actor:, role:, recording:|
  result = RecordingStudioAccessible.grant_access(
    recording: recording,
    actor: actor,
    role: role,
    manager_actor: admin
  )
  raise result.error if result.failure?
end

Current.actor = admin

owned_root_recordings = [
  root_recordings.fetch("Studio Workspace"),
  root_recordings.fetch("Client Alpha"),
  root_recordings.fetch("Client Beta"),
  team_root_recording
]
owned_root_recordings.each { |recording| ensure_owner_access.call(recording: recording) }

[
  root_recordings.fetch("Studio Workspace"),
  root_recordings.fetch("Client Alpha"),
  team_root_recording
].each do |recording|
  ensure_granted_access.call(actor: viewer, role: :view, recording: recording)
end

pages_by_workspace.each do |workspace_name, page_definitions|
  root_recording = root_recordings.fetch(workspace_name)
  existing_page_recordings = root_recording.recordings_query(type: Page).includes(:recordable).to_a

  page_definitions.each do |page_definition|
    page_recording = existing_page_recordings.find do |recording|
      recording.recordable.title == page_definition.fetch(:title)
    end

    if page_recording
      Page.where(id: page_recording.recordable_id).update_all(
        title: page_definition.fetch(:title),
        body: page_definition.fetch(:body),
        updated_at: Time.current
      )
      next
    end

    root_recording.record(Page, actor: admin) do |page|
      page.title = page_definition.fetch(:title)
      page.body = page_definition.fetch(:body)
    end
  end
end

DemoUsers.all.each do |demo_user|
  puts "Seeded: #{demo_user.fetch(:name)} (#{demo_user.fetch(:email)}) / #{demo_user.fetch(:password)}"
end
puts "Seeded scopes: all_workspaces, client_workspaces"
puts "Seeded roots: #{root_recordings.keys.join(', ')}"
puts "Seeded non-workspace root: #{team.name} (Team)"
puts "Seeded shared root: #{message_root.name} (MessageRoot / shared: true)"
puts "Seeded note: Team is accessible but not switchable because switchable_root_types only allows Workspace and Page"
puts "Seeded note: MessageRoot is never switchable because shared roots are domain forests, not owned buckets"
puts "Seeded pages: #{pages_by_workspace.transform_values { |pages| pages.map { |page| page.fetch(:title) } }}"
