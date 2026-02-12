# frozen_string_literal: true

class ExportJobPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin? && (record.requested_by_id.nil? || record.requested_by_id == user&.id)
  def create? = admin?
  def new? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      scope.recent
    end
  end

  private

  def admin?
    user.present?
  end
end
