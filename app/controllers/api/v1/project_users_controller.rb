class Api::V1::ProjectUsersController < Api::V1::ApiController
  def index
    skip_authorization
    project = current_user.projects.find(params[:project_id])

    options = {}
    options[:params] = { project: project }
    render json: UserSerializer.new(project.users, options).serialized_json
  end

  def create
    project = current_user.projects.find(params[:project_id])
    user = User.find_by!(email: params[:email])

    project_user = ProjectUser.new
    project_user.project = project
    project_user.user = user

    # The default role of a user for a project that belongs to an organization
    # is the role the user has in the organization.
    user_organization_role = project.organization ? project.organization.role_of(user) : nil
    if user_organization_role
      project_user.role = user_organization_role
    end

    authorize project_user

    if !project.project_users.include?(user)
      project_user.save!

      project_column = ProjectColumn.new
      project_column.project = project
      project_column.user = user
      project_column.save!

      render json: {
        message: 'Successfully added user to the project.'
      }
    else
      render json: {
        errors: [
          {
            details: 'User is already in the project.'
          }
        ]
      }
    end
  end

  def destroy
    project = current_user.projects.find(params[:project_id])
    project_user = ProjectUser.find_by!(user_id: params[:id], project_id: project.id)

    if params[:id] == current_user.id
      skip_authorization
    else
      authorize project_user
    end

    if current_user.id == params[:id] && project.users.count == 1
      render json: {
        errors: [
          {
            details: "You can't remove yourself from the project if you are the only member"
          }
        ]
      }, status: :bad_request
      return
    end

    project_user.destroy

    render json: {
      message: 'User removed from project'
    }
  end

  def update
    project = current_user.projects.find(params[:project_id])
    project_user = ProjectUser.find_by(project_id: project.id, user_id: params[:id])

    unless project_user
      user = User.find(params[:id])
      project_user = ProjectUser.new
      project_user.project = project
      project_user.user = user
    end

    # The least privileged role of a user for a project that belongs to an organization
    # is the role the user has in the organization.
    user_organization_role = project.organization ? project.organization.role_of(project_user.user) : nil
    if user_organization_role && helpers.higher_role?(user_organization_role, params[:role])
      render json: {
        errors: [
          {
            details: 'The role of a user for a project must not be lower than the role the user has in the organization.'
          }
        ]
      }, status: :bad_request
      skip_authorization
      return
    end

    project_user.role = params[:role]
    authorize project_user

    project_organization_has_owner = project.organization ? project.organization.organization_users.where(role: 'owner').size >= 1 : false

    # Don't allow the last owner of the project to change his role.
    # There should always be at least one owner.
    if project.project_users.where(role: 'owner').size == 1 && project_user.role_changed? && project_user.role_was == 'owner' && !project_organization_has_owner
      render json: {
        errors: [
          {
            details: 'There must always be at least one owner in a project.'
          }
        ]
      }, status: :bad_request
      return
    end

    project_user.save!

    render json: {
      message: 'User role updated'
    }
  end
end
