# frozen_string_literal: true

module Staff
  class Cost
    def self.monthly_cost(year, month)
      new.monthly_cost(year, month)
    end

    def self.distribution(year, month)
      new.distribution(year, month)
    end

    def monthly_cost(year, month)
      worklogs = Budget::StaffWorklog.in_year_month(year, month).includes(:staff_profile)
      by_staff = worklogs.group_by(&:staff_profile_id)
      staff_totals = by_staff.map do |profile_id, logs|
        profile = logs.first.staff_profile
        mandays = logs.sum(&:mandays).to_f
        cost = mandays * profile.internal_day_rate.to_f
        {
          staff_profile: profile,
          mandays: mandays,
          cost: cost.round(2)
        }
      end
      {
        by_staff: staff_totals,
        total_mandays: staff_totals.sum { |s| s[:mandays] }.round(2),
        total_cost: staff_totals.sum { |s| s[:cost] }.round(2)
      }
    end

    def distribution(year, month)
      worklogs = Budget::StaffWorklog.in_year_month(year, month).includes(:staff_profile)
      with_linked = worklogs.select { |w| w.linked_type.present? }
      by_linked = with_linked.group_by { |w| [w.linked_type, w.linked_id] }
      by_linked.map do |(linked_type, linked_id), logs|
        mandays = logs.sum(&:mandays).to_f
        cost = logs.sum { |w| w.mandays.to_f * w.staff_profile.internal_day_rate.to_f }.round(2)
        {
          linked_type: linked_type,
          linked_id: linked_id,
          label: linked_label(linked_type, linked_id),
          mandays: mandays,
          cost: cost
        }
      end
    end

    private

    def linked_label(linked_type, linked_id)
      return "—" if linked_type.blank?
      klass = linked_type.constantize rescue nil
      return "#{linked_type} ##{linked_id}" unless klass
      record = klass.find_by(id: linked_id)
      record.respond_to?(:title) ? record.title : record.respond_to?(:name) ? record.name : "#{linked_type} ##{linked_id}"
    rescue
      "#{linked_type} ##{linked_id}"
    end
  end
end
