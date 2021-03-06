class Key < ApplicationRecord
  has_paper_trail

  belongs_to :project
  has_many :translations, dependent: :destroy

  validates :name, presence: true
  validate :no_duplicate_key_for_project

  before_validation :strip_leading_and_trailing_whitespace

  # Validates that there are no keys with same name
  # for a project.
  def no_duplicate_key_for_project
    project = Project.find(project_id)
    key = project.keys.find_by(name: name)

    if key.present?
      updating_key = key.id == id

      errors.add(:name, 'Name is already in use.') if !updating_key
    end
  end

  protected

  def strip_leading_and_trailing_whitespace
    self.name = name.strip
  end
end
