# frozen_string_literal: true
class Command < ActiveRecord::Base
  has_paper_trail skip: [:updated_at, :created_at]

  has_many :stage_commands
  has_many :stages, through: :stage_commands
  has_many :projects, foreign_key: :build_command_id

  belongs_to :project, optional: true

  validates :command, presence: true

  after_save :trigger_stage_change, if: -> { saved_change_to_attribute? :command }

  def self.global
    where(project_id: nil)
  end

  # used commands in front then all available
  def self.for_object(object)
    usages = usage_ids
    available = Command.for_project(object.project).sort_by { |c| -usages.count(c.id) }
    (object.commands + available).uniq
  end

  def self.for_project(project)
    if project&.persisted?
      where('project_id IS NULL OR project_id = ?', project.id)
    else
      global
    end
  end

  def global?
    project_id.nil?
  end

  def usages
    stages + projects
  end

  def self.usage_ids
    StageCommand.pluck(:command_id) +
    Project.pluck(:build_command_id)
  end

  private

  def trigger_stage_change
    stages.each do |stage|
      # allow stage access to command_was since that is what paper-trail should store
      me = stage.commands.detect { |c| c == self }
      me.raw_write_attribute "command", attribute_before_last_save("command")
      stage.record_script_change
    end
  end
end
